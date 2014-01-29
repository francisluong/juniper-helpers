package provide JuniperConnect 1.0
package require textproc 1.0
package require Expect  5.45
package require Tcl     8.5

namespace eval ::juniperconnect {
  namespace export connectssh disconnectssh send_textblock grep_output import_userpass

  variable session_array
  array unset session_array
  array set session_array {}

  variable basic_rp_prompt_regexp
  set basic_rp_prompt_regexp {[>#%]}

  variable rp_prompt_array
  set rp_prompt_array(Juniper) {([a-z]+@[a-zA-Z0-9\.\-\_]+[>#%])}

  variable expect_timeout 10
  variable expect_timeout_restore $expect_timeout
  variable output {}

  variable netconf_hello 
  array unset netconf_hello
  array set netconf_hello {}

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
    if {[file exists $filepath]} {
      catch {file attributes $filepath -permissions "00600"}
      set file_handle [open $filepath r]
      set file_contents [read $file_handle]
      close $file_handle
      set nlist_user_pass [split [string trim $file_contents] "\n"]
      foreach {user pass} $nlist_user_pass {
        set user [string trim $user]
        set pass [string trim $pass]
        set juniperconnect::r_db($user) $pass
      }
      set juniperconnect::r_username [string trim [lindex $nlist_user_pass 0]]
      set juniperconnect::r_password [string trim [lindex $nlist_user_pass 1]]
      set r_db(__lastuser) $juniperconnect::r_username
    } else {
      puts "[info proc]: $filepath doesn't exist"
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
    set r_password $rdb($username)
  }

  proc restore_lastuser {} {
    #revert r_username and r_password
    # convenience proc for temporary login changes
    variable r_db
    return [change_rdb_user $r_db(__lastuser)]
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
    set prompt $rp_prompt_array(Juniper)
    set success 0
    set send_slow {1 .1}
    set retries 10
    set ssh_mismatch_msg "ERROR: FATAL: Mismatched SSH host key for $address"
    if {$username == "-1"} {
      set username $juniperconnect::r_username
    }
    if {$password == "-1"} {
      set password $juniperconnect::r_password
    }
    while {$success==0 && $retries>0} {
      switch -- $style {
        "cli" {
          set catch_result [ catch {spawn ssh $username@$address} reason ]
        }
        "netconf" {
          log_user 0
          set catch_result [ catch {spawn ssh $username@$address -p 830 -s "netconf"} reason ]
        }
        default {
          return -code error "[info proc]: ERROR: unexpected value for style: '$style'"
        }
      }
      set netconf_tags {}
      if {$catch_result>0} {
        return -code error "juniperconnect::connectssh $username@$address: failed to connect: $reason\n"
      }
      set timeout 120
      send "\n"
      expect {
        {]]>]]>} {
          if {$style eq "netconf"} {
            append netconf_tags $expect_out(buffer)
            set success 1
          } else {
            exp_continue
          }
        }
        -re "<.*>" {
          if {$style eq "netconf"} {
            append netconf_tags $expect_out(buffer)
          }
          exp_continue
        }
        -re "(Last login: |$prompt)" {
          set success 1
        }
        "no hostkey alg" {
          return -code error "ERROR: juniperconnect::connectssh: no hostkey alg"
        }
        "Host key verification failed." {
          return -code error $ssh_mismatch_msg
        }
        "REMOTE HOST IDENTIFICATION HAS CHANGED" {
          return -code error $ssh_mismatch_msg
        }
        "Could not resolve hostname"              {
           puts "juniperconnect::connectssh: $expect_out(0,string)"
           exp_close; exp_wait
           set retries -2
           break
        }
        "Permission denied, please try again" {
           puts "juniperconnect::connectssh: $expect_out(0,string)"
           exp_close; exp_wait
           set retries -1
           break
        }
        "% Bad passwords" {
           puts "juniperconnect::connectssh: $expect_out(0,string)"
           exp_close; exp_wait
           set retries -1
           break
        }
        "can't be established." {
          expect {(yes/no)?} {
            send "yes\r"
          }
          exp_continue
        }
        -re "Connection (refused|closed)" {
          puts "juniperconnect::connectssh: $expect_out(0,string)"
          exp_close; exp_wait
          after 2000
        }
        -re "(% Login invalid|Login incorrect|% Authentication failed.|ermission denied|Password Incorrect)" { 
          exp_continue
        }
        -re "( JUNOS )" {
          exp_continue
        }
        -re "(Username: |login: )" {
          send -s "$username\r"
          exp_continue
        }
        -re "($address's password:|Password:|Telnet password:)" {
          send -s "$password\r"
          exp_continue
        }
        timeout {
          return -code error "juniperconnect::connectssh: TIMEOUT: timed out during login into $address"
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
      return -code error "juniperconnect::connectssh: Error count exceeded for error $err_string error"
    }
    set timeout 10
    log_user 1
    switch -- $style {
      "cli" {
        puts "\njuniperconnect::connectssh success"
        set session_array($address) $spawn_id
        send_textblock $address "
          set cli screen-length 0
          set cli screen-width 0
        "
      }
      "netconf" {
        #parse or store netconf_tags
        set netconf_tags [string trim [lindex [split $netconf_tags "\]"] 0]]
        set juniperconnect::netconf_hello($address) $netconf_tags
        #session array storage for netconf... separate one?
        set session_array(nc:$address) $spawn_id
      }
      default {
        return -code error "[info proc]: ERROR: unexpected value for style: '$style'"
      }
    }
    return $spawn_id
  }

  proc disconnectssh {address} {
    variable session_array
    variable rp_prompt_array
    set prompt $rp_prompt_array(Juniper)
    set spawn_id $session_array($address)
    if {$spawn_id ne ""} {
      #send exit
      set timeout 1
      send "exit\n"
      expect -re $prompt {}
      puts "\njuniperconnect::disconnect"
      #close/wait for expect session
      catch {exp_close}
      catch {exp_wait}
      #clear the value stored in the session array
      set session_array($address) ""
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
    set expect_timeout $expect_timeout_restore
  }

  proc timeout {} {
    #get the expect_timeout value
    variable expect_timeout
    return $expect_timeout
  }

  proc send_textblock {address commands_textblock} {
    set textblock [string trim $commands_textblock]
    set commands_list [textproc::nsplit $textblock]
    return [send_commands $address $commands_list]
  }

  proc send_commands {address commands_list} {
    #send a list of commands to the router expecting prompt between each
    variable rp_prompt_array
    set prompt $rp_prompt_array(Juniper)
    set procname "send_commands"
    set tclfilename [namespace current]

    #initialize return output
    variable output
    set output {}

    set timeout [timeout]
    set mode "cli"
    variable session_array
    set spawn_id $session_array($address)

    #send initial carriage-return then expect first prompt
    send "\n"
    expect {
      -re $prompt {append output [string trimleft $expect_out(buffer)]}
      timeout {
        return -code error "ERROR: $procname: TIMEOUT waiting for initial prompt"
      }
    }
    #loop through commands list
    foreach this_command $commands_list {
      #determine if we need to adjust the prompt based on mode switches
      # need a simpler prompt for shell
      switch -- $mode {
        "cli" {
          #if we are in cli mode and we see 'start shell', switch mode/prompt
          switch -- $this_command {
            "start shell" {
              set mode "shell"
              variable basic_rp_prompt_regexp
              #set prompt "%"
              set prompt $basic_rp_prompt_regexp
            }
          }
        }
        "shell" {
          #if we are in shell mode and we see 'exit', switch back to cli
          switch -- $this_command {
            "exit" {
              set mode "cli"
              set prompt $rp_prompt_array(Juniper)
            }
          }
        }
      }
      #send command
      send "$this_command\n"
      #loop and look for for prompt regexp
      expect {
        -re "$prompt" {
          #got prompt - exit condition for expect-loop
          append output $expect_out(buffer)
        }
        -re ".*(\r|\n)" {
          #this resets the timeout timer using newline-continues
          append output $expect_out(buffer)
          exp_continue
        }
        timeout {
          puts "$procname: TIMEOUT waiting for prompt"
          #because of the for-loop this sucker may just keep going, but it's possible the cli has siezed up
        }
      }
    }
    set output [string trimright [textproc::nrange $output 0 end-1]]
    set output [join [split $output "\r"] ""]
    return $output
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

}

namespace import juniperconnect::*

