#!/usr/bin/env tclsh
package provide JuniperConnect 1.0
package require textproc 
package require Expect 5.43
package require Tcl 8.5
package require tdom 0.8.3
package require base64
package require yaml 0.3.6
package require homeless
package require concurrency

namespace eval ::juniperconnect {
    namespace export connectssh disconnectssh send_commands send_textblock send_config build_rpc add_to_rpc send_rpc grep_output import_userpass prep_netconf_output

    variable version 1.0
    variable session_array
    array unset session_array
    array set session_array {}

    variable basic_rp_prompt_regexp
    set basic_rp_prompt_regexp {[>#%]}

    variable rp_prompt_array
    set rp_prompt_array(Juniper) {([a-z]+@[a-zA-Z0-9\.\-\_]+[>#%])}

    variable expect_timeout_default 10
    variable expect_timeout $expect_timeout_default

    #options variable
    # - "outputlevel": 
    #     * normal (default) will allow expect sessions to be echoed to stdout
    #     * quiet will suppress expect session output 
    variable options 
    array unset options
    set options(initialized) 0

    #cli output
    variable output {}

    #netconf output
    variable nc_output {}

    #netconf hello message storage
    variable netconf_hello 
    array unset netconf_hello
    array set netconf_hello {}

    #netconf msgid storage
    variable netconf_msgid 1000

    variable netconf_port 830

    #client capabilities
    variable ncclient_hello_out {
        <hello>
            <capabilities>
                <capability>urn:ietf:params:xml:ns:netconf:base:1.0</capability>
                <capability>urn:ietf:params:xml:ns:netconf:capability:candidate:1.0</capability>
                <capability>urn:ietf:params:xml:ns:netconf:capability:confirmed-commit:1.0</capability>
                <capability>urn:ietf:params:xml:ns:netconf:capability:validate:1.0</capability>
                <capability>urn:ietf:params:xml:ns:netconf:capability:url:1.0?protocol=http,ftp,file</capability>
                <capability>http://xml.juniper.net/netconf/junos/1.0</capability>
            </capabilities>
        </hello>
        ]]>]]>
    }

    #netconf end of message marker
    variable end_of_message {]]>]]>}

    #XSLT to strip namespaces
    # copied from https://github.com/Juniper/ncclient/blob/master/ncclient/xml_.py
    set xslt_remove_namespace [dom parse {
        <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
            <xsl:output method="xml" indent="no"/>

            <!-- Stylesheet to remove all namespaces from a document -->
            <!-- NOTE: this will lead to attribute name clash, if an element contains
                    two attributes with same local name but different namespace prefix -->
            <!-- Nodes that cannot have a namespace are copied as such -->

            <!-- template to copy elements -->
            <xsl:template match="*">
                    <xsl:element name="{local-name()}">
                            <xsl:apply-templates select="@*|node()"/>
                    </xsl:element>
            </xsl:template>

            <!-- template to copy attributes -->
            <xsl:template match="@*">
                    <xsl:attribute name="{local-name()}">
                            <xsl:value-of select="."/>
                    </xsl:attribute>
            </xsl:template>

            <!-- template to the rest of the nodes -->
            <xsl:template match="/|comment()|processing-instruction()|text()">
                    <xsl:copy>
                            <xsl:apply-templates/>
                    </xsl:copy>
            </xsl:template>

        </xsl:stylesheet>
    }]

    #password database
    variable r_db
    array unset r_db
    array set r_db {}
    variable r_username {}
    variable r_password {}

    proc import_userpass {filepath} {
        #open a file containing username and password (each on one line) 
        #assign all of these to the array r_db with index = username, value = password
        #also, set the first two lines as r_username and r_password
        if {[file readable $filepath]} {
            catch {file attributes $filepath -permissions "00600"}
            set file_handle [open $filepath r]
            set file_contents [read $file_handle]
            close $file_handle
            set nlist_user_pass [split [string trim $file_contents] "\n"]
            foreach {user pass} $nlist_user_pass {
                set user [string trim $user]
                set pass [string trim $pass]
                set juniperconnect::r_db($user) [base64::encode $pass]
            }
            set juniperconnect::r_username [string trim [lindex $nlist_user_pass 0]]
            set juniperconnect::r_password [base64::encode [string trim [lindex $nlist_user_pass 1]]]
            set r_db(__lastuser) $juniperconnect::r_username
        } else {
            puts stderr "juniperconnect: ERROR: Userpass file '$filepath' cannot be opened for reading"
            exit 1
        }
    }

    proc change_rdb_user {username} {
        #change r_username and r_password based in the input variable 'username'
        #this will throw an exception if 'username' is not in r_db
        variable r_db
        variable r_username
        variable r_password
        set r_db(__lastuser) $r_username
        set r_username $username
        set r_password $r_db($username)
    }

    proc restore_lastuser {} {
        #revert r_username and r_password
        # convenience proc for temporary login changes
        variable r_db
        return [juniperconnect::change_rdb_user $r_db(__lastuser)]
    }

    proc session_exists {address} {
        #convenience proc to see if a session has already been opened for an address
        set result 0
        if {[info exists juniperconnect::session_array($address)]} {
            set result 1
        }
        return $result
    }

    proc connectssh {address {style "cli"} {username "-1"} {password "-1"}} {
        #a connect needs to be performed before you can send any commands to the router
        # style will be used to handle cli or netconf
        variable session_array
        variable rp_prompt_array
        variable end_of_message
        variable options
        #local
        set output {}
        if {!$options(initialized)} {
            #read in config.yml from same folder as juniperconnect
            set jcpath [lindex [package ifneeded JuniperConnect $juniperconnect::version] end]
            set jcpath [file dir $jcpath]
            set config_dict [yaml::yaml2dict [read_file "${jcpath}/config.yml"]]
            dict for {key value} $config_dict {
                if {![info exists options($key)]} {
                    set options($key) $value
                }
            }
            set options(initialized) 1
        }
        if {$options(outputlevel) eq "quiet"} {
            log_user 0
        }
        #parray options
        set prompt $rp_prompt_array(Juniper)
        set success 0
        set send_slow {1 .1}
        set retries 10
        set ssh_mismatch_msg "ERROR: FATAL: Mismatched SSH host key for $address"
        #parse address and set username if needed
        set address_full $address
        if {$username != "-1"} {
        } elseif {[string match "*@*" $address]} {
            lassign [split $address "@"] username address
        } else {
            set username $juniperconnect::r_username
        }
        if {$username eq ""} {
            puts stderr "juniperconnnect::connectssh ERROR: username is not set!\nEither specify username and password or import_userpass."
            exit
        }
        if {$password == "-1"} {
            set password $juniperconnect::r_password
        } else {
            set password [base64::encode $password]
        }
        while {$success==0 && $retries>0} {
            switch -- $style {
                "cli" {
                    spawn ssh $username@$address
                }
                "netconf" {
                    variable netconf_port
                    spawn ssh $username@$address -p $netconf_port -s "netconf"
                }
                default {
                    return -code error "[info proc]: ERROR: unexpected value for style: '$style'"
                }
            }
            set netconf_tags {}
            set timeout $juniperconnect::options(connect_timeout_sec)
            send "\n"
            expect {
                $end_of_message {
                    append output $expect_out(buffer)
                    if {$style eq "netconf"} {
                        append netconf_tags $expect_out(buffer)
                        set success 1
                    } else {
                        exp_continue
                    }
                }
                -re "<.*>" {
                    append output $expect_out(buffer)
                    if {$style eq "netconf"} {
                        append netconf_tags $expect_out(buffer)
                    }
                    exp_continue
                }
                -re $prompt {
                    append output $expect_out(buffer)
                    if {$style eq "cli"} {
                        set success 1
                    } else {
                        exp_continue
                    }
                }
                "no hostkey alg" {
                    append output $expect_out(buffer)
                    return -code error "ERROR: juniperconnect::connectssh: no hostkey alg\n$output"
                }
                -re "host key .*( verification failed|differs).*" {
                    append output $expect_out(buffer)
                    return -code error "$ssh_mismatch_msg\n$output"
                }
                "REMOTE HOST IDENTIFICATION HAS CHANGED" {
                    append output $expect_out(buffer)
                    return -code error "$ssh_mismatch_msg\n$output"
                }
                -re "(Could not resolve hostname|node name or service name not known)" {
                    append output $expect_out(buffer)
                      puts "juniperconnect::connectssh: $expect_out(0,string)"
                      exp_close; exp_wait
                      set retries -2
                      break
                }
                "Permission denied, please try again" {
                    append output $expect_out(buffer)
                      puts "juniperconnect::connectssh: $expect_out(0,string)"
                      exp_close; exp_wait
                      set retries -1
                      break
                }
                "% Bad passwords" {
                    append output $expect_out(buffer)
                      puts "juniperconnect::connectssh: $expect_out(0,string)"
                      exp_close; exp_wait
                      set retries -1
                      break
                }
                "can't be established." {
                    append output $expect_out(buffer)
                    expect {(yes/no)?} {
                        send "yes\r"
                    }
                    exp_continue
                }
                -re "Connection (refused|closed)" {
                    append output $expect_out(buffer)
                    puts "juniperconnect::connectssh: $expect_out(0,string)"
                    exp_close; exp_wait
                    after 2000
                }
                -re "(% Login invalid|Login incorrect|% Authentication failed.|ermission denied|Password Incorrect)" { 
                    append output $expect_out(buffer)
                    exp_continue
                }
                -re "( JUNOS )" {
                    append output $expect_out(buffer)
                    exp_continue
                }
                -re "(Username: |login: )" {
                    append output $expect_out(buffer)
                    send "$username\r"
                    exp_continue
                }
                -re "($address's password:|Password:|Telnet password:)" {
                    append output $expect_out(buffer)
                    send "[base64::decode $password]\r"
                    exp_continue
                }
                timeout {
                    return -code error "juniperconnect::connectssh: TIMEOUT: timed out during login into $address\n$output"
                }
            }
            after 1000
            incr retries -1
        }
        if {$retries<1} {
            switch -- $retries {
                "0"       {set err_string "'Connection refused'" }
                "-1"      {set err_string "'Bad passwords'" }
                "-2"      {set err_string "'Bad Hostname'" }
            }
            return -code error "juniperconnect::connectssh: Error count exceeded for error $err_string error\n$output"
        }
        set timeout [juniperconnect::timeout]
        switch -- $style {
            "cli" {
                if {$options(outputlevel) ne "quiet" } {
                    puts "\njuniperconnect::connectssh $address success"
                }
                set session_array($address_full) $spawn_id
                send "set cli screen-length 0\n"
                expect -re $prompt {send "set cli screen-width 1024\n"}
                expect -re $prompt {send "set cli timestamp\n"}
                expect -re $prompt {send "\n"}
                expect -re $prompt {}
                #absorb final prompt
            }
            "netconf" {
                #parse or store netconf_tags
                set netconf_tags [string trim [lindex [split $netconf_tags "\]"] 0]]
                set juniperconnect::netconf_hello($address) $netconf_tags
                #send our hello
                variable ncclient_hello_out
                send $ncclient_hello_out
                expect $end_of_message {}
                #session array storage for netconf... separate one?
                set session_array(nc:$address_full) $spawn_id
            }
            default {
                return -code error "[info proc]: ERROR: unexpected value for style: '$style'"
            }
        }
        log_user 1
        return $spawn_id
    }

    proc disconnectssh {address {style "cli"}} {
        variable session_array
        variable rp_prompt_array
        set prompt $rp_prompt_array(Juniper)
        switch -- $style {
            "netconf" {
                if {[string match "nc:*" $address]} {
                    set index $address
                } else {
                    set index "nc:$address"
                }
            }
            default {
                set index $address
            }
        }
        set spawn_id $session_array($index)
        if {$spawn_id ne ""} {
            if {[string match "nc:*" $index]} {
                #close NETCONF session
                set address [lindex [split $address ":"] end]
                juniperconnect::send_rpc $address [juniperconnect::build_rpc "close-session"]
            } else {
                #CLI: send exit
                set timeout 1
                send "exit\n"
                expect -re $prompt {}
            }
            puts "\njuniperconnect::disconnect ($address/$index)"
            #close/wait for expect session
            catch {exp_close}
            catch {exp_wait}
            #clear the value stored in the session array
            unset session_array($index)
        }
    }

    proc set_timeout {timeout_value_sec} {
        #set the expect_timeout value
        variable expect_timeout
        set expect_timeout $timeout_value_sec
    }

    proc restore_timeout {} {
        #revert the expect_timeout value to default
        variable expect_timeout
        variable expect_timeout_default
        #we get the timeout from config.yml:timeout_sec
        set expect_timeout $juniperconnect::options(timeout_sec)
    }

    proc timeout {} {
        #get the expect_timeout value
        variable expect_timeout
        return $expect_timeout
    }

    #======================
    #CLI EXTERNAL
    #======================

    proc send_textblock {address commands_textblock} {
        set textblock [string trim $commands_textblock]
        set commands_list [textproc::nsplit $textblock]
        return [[namespace current]::send_commands $address $commands_list]
    }

    proc send_commands {address commands_list} {
        #send a list of commands to the router expecting prompt between each
        variable rp_prompt_array
        set prompt $rp_prompt_array(Juniper)
        set procname "send_commands"

        #initialize return output
        variable output
        set output {}

        set timeout [[namespace current]::timeout]
        set spawn_id $juniperconnect::session_array($address)

        #suppress output if outputlevel is set to quiet
        variable options
        if {$options(outputlevel) eq "quiet"} {
            log_user 0
        }

        #send initial carriage-return then expect first prompt
        _verify_initial_send_prompt $address
        #loop through commands list
        [namespace current]::_send_commands_loop $address $commands_list
        set output [string trimright [textproc::nrange $output 0 end-1]]
        set output [join [split $output "\r"] ""]
        log_user 1
        #strip bells from output
        set ding {\007}
        regsub -all $ding $output "" output
        return $output
    }

    proc send_config {address config_textblock {merge_set_override "cli"} {confirmed_simulate "0"}} {
        #send a list of commands to the router expecting prompt between each
        set prompt $juniperconnect::rp_prompt_array(Juniper)
        set procname "send_config"

        #initialize return output
        variable output
        set output {}

        set timeout [juniperconnect::timeout]
        set spawn_id $juniperconnect::session_array($address)

        #suppress output if outputlevel is set to quiet
        variable options
        if {$options(outputlevel) eq "quiet"} {
            log_user 0
        }

        #send initial carriage-return then expect first prompt
        juniperconnect::_verify_initial_send_prompt $address
        #enter configuration mode
        juniperconnect::_enter_configuration_mode $address $confirmed_simulate
        #initiate load
        set config_textblock [string trim $config_textblock]
        switch -- $merge_set_override {
            "patch" -
            "override" -
            "set" -
            "merge" {
                #load set/merge/patch/override terminal
                send "load $merge_set_override terminal\r"
                set timeout $juniperconnect::options(load_timeout_sec)
                expect {
                    -re "\[a-zA-Z ]+" {}
                    timeout {
                        return -code error "$procname: TIMEOUT($timeout) waiting for 'load start'"
                    }
                }
                #loop through config textblock
                foreach line [textproc::nsplit $config_textblock] {
                    set line [string trimleft $line]
                    #insert delay
                    after 10
                    expect -re ".*(\r|\n)" {
                        append output $expect_out(buffer)
                    }
                    send "$line\r"
                }
                #send CTRL-d every second until we get a prompt or we hit the timeout_max
                send "\r\004"
                set timeout_max $timeout
                set timeout 1
                set this_iter 0
                expect {
                    "load complete" {
                        append output [string trimleft $expect_out(buffer)]
                    }
                    timeout {
                        incr this_iter
                        if {$this_iter >= $timeout_max} {
                            return -code error "$procname: TIMEOUT($timeout) waiting for 'load complete'"
                        } else {
                            send "\004"
                            exp_continue
                        }
                    }
                }
                #revert timeout
                set timeout [juniperconnect::timeout]
                expect {
                    -re $prompt {
                        append output [string trimleft $expect_out(buffer)]
                        #absorb final prompt
                    }
                    timeout {
                        return -code error "$procname: TIMEOUT($timeout) waiting for prompt after 'load complete'"
                    }
                }
            }
            "cli" {
                #default mode... act like send_commands
                set commands_list [nsplit $config_textblock]
                juniperconnect::_send_commands_loop $address $commands_list
            }
            default {
                return -code error "ERROR: unexpected value for merge_set_override: $merge_set_override"
            }
        }
        _commit_and_quit_config $address $confirmed_simulate
        set output [string trimright [textproc::nrange $output 0 end-1]]
        set output [join [split $output "\r"] ""]
        log_user 1
        return $output
    }

    #======================
    #CLI Internal
    #======================

    proc _verify_initial_send_prompt {address {capture_output 1}} {
        set procname "_verify_initial_send_prompt"
        variable session_array
        variable timeout
        variable rp_prompt_array
        variable output
        set spawn_id $session_array($address)
        set timeout [[namespace current]::timeout]
        set prompt $rp_prompt_array(Juniper)
        send "\n"
        expect {
            -re $prompt {
                if {$capture_output} {
                    append output [string trimleft $expect_out(buffer)]
                }
                #absorb final prompt
            }
            -re ".*(\r|\n)" {
                #this resets the timeout timer using newline-continues
                append output $expect_out(buffer)
                exp_continue
            }
            timeout {
                return -code error "ERROR: $procname: TIMEOUT waiting for prompt"
            }
        }
    }

    proc _enter_configuration_mode {address confirmed_simulate {loose "0"}} {
        variable output
        set spawn_id $juniperconnect::session_array($address)
        set timeout [juniperconnect::timeout]
        set prompt $juniperconnect::rp_prompt_array(Juniper)
        switch -glob -nocase -- $confirmed_simulate {
            "*confirm*" {
                send "configure exclusive\r"
            }
            default {
                send "configure private\r"
            }
        }
        if {$loose == 0} {
            #NOT loose
            expect {
                "commit confirmed will be rolled back in" {
                    return -code error "ERROR: Juniper router $address has pending rollback"
                    exp_continue
                }
                "The configuration has been changed but not committed" {
                    return -code error "ERROR: Juniper router $address has uncommited changes - exitting"
                    exp_continue
                }
                "Entering configuration mode" {
                    append output [string trimleft $expect_out(buffer)]
                }
            }
        } else {
            #loose/permissive
            expect {
                "Entering configuration mode" {
                    append output [string trimleft $expect_out(buffer)]
                }
            }
        }
        expect {
            -re $prompt {
                append output [string trimleft $expect_out(buffer)]
                #absorb final prompt
            }
            timeout {
                return -code error "ERROR: $procname: TIMEOUT waiting for initial prompt"
            }
        }
    }

    proc _prep_for_next_send {address} {
        #absorb final prompt... new send directives start with sending a newline
        set spawn_id $juniperconnect::session_array($address)
        set timeout 1
        set prompt $juniperconnect::rp_prompt_array(Juniper)
        log_user 0
        expect {
            -re $prompt {
            }
        }
        log_user 1
    }

    proc _send_commands_loop {address commands_list} {
        variable output
        set procname "_send_commands_loop"
        set spawn_id $juniperconnect::session_array($address)
        set timeout [juniperconnect::timeout]
        set mode "cli"
        set prompt $juniperconnect::rp_prompt_array(Juniper)
        foreach this_command $commands_list {
            #determine if we need to adjust the prompt based on mode switches
            # need a simpler prompt for shell
            switch -- $mode {
                "cli" {
                    #if we are in cli mode and we see 'start shell', switch mode/prompt
                    switch -- $this_command {
                        "start shell" {
                            set mode "shell"
                            set prompt $juniperconnect::basic_rp_prompt_regexp
                        }
                    }
                }
                "shell" {
                    #if we are in shell mode and we see 'exit', switch back to cli
                    switch -- $this_command {
                        "exit" {
                            set mode "cli"
                            set prompt $juniperconnect::rp_prompt_array(Juniper)
                        }
                    }
                }
            }
            #send command
            send "$this_command\n"
            set output_received 0
            #loop and look for for prompt regexp
            expect {
                -re $prompt {
                    #got prompt - exit condition for expect-loop
                    append output $expect_out(buffer)
                    if {!$output_received} {
                        exp_continue
                    }
                }
                -re ".*(\r|\n)" {
                    #this resets the timeout timer using newline-continues
                    set output_received 1
                    append output $expect_out(buffer)
                    exp_continue
                }
                timeout {
                    puts "$procname: TIMEOUT($timeout) waiting for prompt"
                    #no crash because of the for-loop this sucker may just keep going, but it's possible the cli has siezed up
                }
            }
        }
        #final prompt is absorbed
    }

    proc _commit_and_quit_config {address {confirmed_simulate "0"}} {
        variable output
        set procname "_commit_and_quit_config"
        set prompt $juniperconnect::rp_prompt_array(Juniper)
        set spawn_id $juniperconnect::session_array($address)
        set timeout $juniperconnect::options(commit_timeout_sec)
        [namespace current]::_send_commands_loop $address [textproc::nsplit "
            show | compare | count
            show | compare
        "]
        #send commit
        switch -glob -nocase -- $confirmed_simulate {
            "*confirm*" {
                #perform commit check
                [namespace current]::_send_commands_loop $address [list "commit check"]
                #issue commit confirmed
                set minutes $juniperconnect::options(commit_confirmed_timeout_min)
                send "commit confirmed $minutes and-quit\r"
            }
            "*check*" -
            "*test*" -
            "*simulate*" {
                #do nothing
            } 
            default {
                send "commit and-quit\r"
            }
        }
        #process commit - if we do not get commit complete, rollback and throw an exception
        switch -glob -nocase -- $confirmed_simulate {
            "*check*" -
            "*test*" -
            "*simulate*" {
                set commands_list [list "commit check" "rollback" "quit config"]
                juniperconnect::_send_commands_loop $address $commands_list
            } 
            "*confirm*" -
            default {
                set commit_complete 0
                expect {
                    "commit complete" {
                        append output $expect_out(buffer)
                        set commit_complete 1
                        exp_continue
                    }
                    "error: configuration check-out failed" {
                        return -code error "ERROR: Juniper configuration commit failed" 
                    }
                    {re0:} {
                        append output $expect_out(buffer)
                        exp_continue
                    }
                    {re1:} {
                        append output $expect_out(buffer)
                        exp_continue
                    }
                    "configuration check succeeds" {
                        append output $expect_out(buffer)
                        exp_continue
                    }
                    -re $prompt {
                        append output $expect_out(buffer)
                        if {!$commit_complete} {
                            #send rollback and quit-configuration
                            set commands_list [list "rollback" "quit config"]
                            juniperconnect::_send_commands_loop $address $commands_list
                            #throw exception
                            return -code error "ERROR: $procname: got prompt before seeing 'commit complete'"
                        }
                        #absorb final prompt
                    }
                    timeout {
                        return -code error "EXPECT TIMEOUT($timeout): $procname: waiting for final prompt"
                    }
                }
            }
        }
        #if commit confirmed, send second commit
        if {[string match -nocase "*confirm*" $confirmed_simulate]} {
            #disconnect
            disconnectssh $address
            #reconnect
            set spawn_id [connectssh $address]
            #enter configuration mode
            _enter_configuration_mode $address $confirmed_simulate "loose"
            _commit_and_quit_config $address
        }
        set timeout [juniperconnect::timeout]
    }

    #======================
    #NETCONF SPECIFIC
    #======================

    proc add_to_rpc {input_xml_text path_statement_textblock {indent "0"}} {
        #syntactic sugar for build_rpc to add additional elements
        # since there's no clean way to go up in level
        return [[namespace current]::build_rpc $path_statement_textblock $indent $input_xml_text]
    }

    proc build_rpc {path_statement_textblock {indent "0"} {input_xml_text ""}} {
        variable netconf_msgid
        set this_msgid $netconf_msgid
        incr netconf_msgid
        if {$input_xml_text eq ""} {
            #start a new document
            set rpc [dom createDocument "rpc"]
        } else {
            #add to existing document
            set rpc [dom parse $input_xml_text]
        }
        set root [$rpc documentElement]
        $root setAttribute "message-id" $this_msgid
        foreach path_statement [nsplit $path_statement_textblock] {
            set path_statement [string trim $path_statement]
            set current_node $root
            foreach element_list [split $path_statement "/"] {
                foreach element [split $element_list ","] {
                    #probably will need to add logic to handle attributes and text
                    if {[string match "@*" $element]} {
                        #add attribute to current node
                        set this_element [string trimleft $element "@"]
                        lassign [split $this_element "="] tag value
                        set value [string trim $value {'\"}]
                        $current_node setAttribute $tag $value
                    } elseif {[string match "*=*" $element]} {
                        #add node and text
                        lassign [split $element "="] tag value
                        set value [string trim $value {'\"}]
                        #need to also create a text node and attach it
                        set new_node [$rpc createElement $tag]
                        $current_node appendChild $new_node
                        set text_node [$rpc createTextNode $value]
                        $new_node appendChild $text_node
                        set current_node $new_node
                    } else {
                        #see if this element already exists
                        set result_node_set [$current_node selectNodes $element]
                        if {$result_node_set eq ""} {
                            #new child node element
                            set new_node [$rpc createElement $element]
                            $current_node appendChild $new_node
                            set current_node $new_node
                        } else {
                            #node exists... switch to node
                            set current_node [lindex $result_node_set 0]
                        }
                    }
                }
            }
        }
        variable end_of_message
        #set result "[$root asXML -indent none]$end_of_message"
        set result [$root asXML -indent $indent]
        return $result
    }

    proc add_ascii_format_to_rpc {rpc_request {indent "none"}} {
        set doc [dom parse $rpc_request]
        set rpc [$doc firstChild]
        set node [$rpc firstChild]
        $node setAttribute format "ascii"
        set result [$doc asXML -indent $indent]
    }

    proc send_rpc {address rpc {style "strip"}} {
        #send netconf rpc to the router and return the nc_output
        set procname "send_rpc"

        set this_nc_output {}

        set timeout [juniperconnect::timeout]
        set mode "netconf"

        variable session_array
        set spawn_id $session_array(nc:$address)

        #suppress output if outputlevel is set to quiet
        variable options
        if {$options(outputlevel) eq "quiet"} {
            log_user 0
        }

        variable end_of_message

        #send rpc and end sequence
        set send_slow {10 .001}
        if {$options(outputlevel) ne "quiet"} {
            puts "\n[[dom parse $rpc] asXML -indent 4]\n"
        }
        log_user 0
        send "[string trim $rpc]$end_of_message\n"
        expect $end_of_message {}
        if {$options(outputlevel) ne "quiet"} {
            log_user 1
        }

        #loop through return this_nc_output until end_of_message received
        expect {
            $end_of_message {
                #got end_of_message - exit condition for expect-loop
                append this_nc_output $expect_out(buffer)
            }
            -re "<.*>" {
                #this resets the timeout timer when we find any tag/element
                append this_nc_output $expect_out(buffer)
                exp_continue
            }
            timeout {
                puts "$procname: TIMEOUT waiting for end-of-message marker"
                #because of the for-loop this sucker may just keep going, but it's possible the cli has siezed up
            }
        }
        log_user 1
        set this_nc_output [nrange $this_nc_output 1 end-1]
        #puts "==="
        #puts $this_nc_output
        #puts "==="
        switch -- $style {
            "ascii" {
                set rpc_ascii [add_ascii_format_to_rpc $rpc]
                set ascii_output [juniperconnect::send_rpc $address $rpc_ascii]
                return [[namespace current]::prep_netconf_output $this_nc_output $style $ascii_output]
            }
            default {
                return [[namespace current]::prep_netconf_output $this_nc_output $style]
            }
        }
    }

    proc prep_netconf_output {netconf_output {style "strip"} {ascii_output ""}} {
        variable xslt_remove_namespace
        set netconf_output [textproc::grep_until "rpc-reply" "/rpc-reply" $netconf_output]
        set netconf_output [lindex $netconf_output 0]
        set this_doc [dom parse $netconf_output]
        $this_doc xslt $xslt_remove_namespace cleandoc
        switch -- $style {
            default -
            "strip" {
            }
            "raw" {
                set cleandoc $this_doc
            }
            "ascii" {
                if {$ascii_output ne ""} {
                    set ascii_doc [dom parse $ascii_output]
                    set outputnode [$ascii_doc selectNodes "//output"]
                    #fallback to first child node if select returns empty set
                    if {$outputnode eq ""} {
                        set outputnode [$ascii_doc firstChild]
                    }
                    set rpc_reply [$cleandoc firstChild]
                    $rpc_reply appendChild $outputnode
                }
            }
        }
        set result [$cleandoc asXML]
        if {[info exists outputnode]} {
            $outputnode delete
        }
        $cleandoc delete
        $this_doc delete
        variable nc_output
        set nc_output $result
        return $result
    }

    proc grep_output {expression} {
        return [textproc::linematch $expression $juniperconnect::output]
    }

    proc get_hello {address} {
        set result {}
        variable netconf_hello
        set index [lsearch [array names netconf_hello] $address] 
        if {$index != -1} {
            set result $netconf_hello($address)
        }
        return $result
    }

    proc quiet {{level "quiet"}} {
        variable options
        set options(outputlevel) $level
    }

    #======================
    # Concurrency Hooks
    #======================

    proc _concurrency_iteration {address} {
        #child needs to call iter_thread_start as first action
        concurrency::iter_thread_start
        set options [concurrency::iter_get_stdin_dict]
        if {$concurrency::debug} {
            output::pdict options
        }
        # get the "action"
        set action [dict get $options "action"]
        set pass 1
        switch -- $action {
            "send_config" {
                set router [dict get $options router]
                set commands_textblock [dict get $options commands_textblock]
                set merge_set_override [dict get $options merge_set_override]
                set confirmed_simulate [dict get $options confirmed_simulate]
                juniperconnect::connectssh $router
                set output [juniperconnect::send_config $router $commands_textblock \
                    $merge_set_override $confirmed_simulate]
                concurrency::iter_output $output
                if {![string match "*commit complete*" $output]} {
                    set pass 0
                }
                juniperconnect::disconnectssh $router
            }
            "send_textblock" {
                set router [dict get $options router]
                set commands_textblock [dict get $options commands_textblock]
                juniperconnect::connectssh $router
                set output [juniperconnect::send_textblock $router $commands_textblock]
                concurrency::iter_output $output
                juniperconnect::disconnectssh $router
            }
            default {
            }
        }
        #invert pass to get returncode
        if {$pass} {
            set returncode 0
        } else {
            set returncode 1
        }
        #child thread proc needs to call iter_thread_finish as final action with return code as only arg
        concurrency::iter_thread_finish $returncode
    }

    proc send_textblock_concurrent {routers_list commands_textblock {debug "0"}} {
        package require output
        set oldcdebug $concurrency::debug
        if {$debug} {
            set concurrency::debug $debug
        }
        concurrency::init juniperconnect::concurrency_init
        concurrency::data "commands_textblock" [string trim $commands_textblock]
        concurrency::data "action" "send_textblock"
        set library_path [lindex [package ifneeded JuniperConnect $juniperconnect::version] end]
        concurrency::process_queue $routers_list "juniperconnect::_concurrency_ipc_gen" $library_path
            set concurrency::debug $oldcdebug
        return [array get concurrency::results_array]
    }

    proc _concurrency_ipc_gen {address}  {
        dict set options "router" $address
        #pack into yaml and return
        return $options
    }

}

namespace import juniperconnect::*
if {[string match "*juniper_connect.tcl" $argv0]} {
    package require output
    concurrency::init "juniperconnect::_concurrency_iteration"
}
