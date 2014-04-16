#!/usr/bin/env tclsh

package require gen
package require test
package require concurrency
package require yaml

#set concurrency::debug 1

#usage
if {$argc < 3} {
    puts stderr "Usage: [info script] <userpass_file> <yaml_config_gen_file> <router1> \[<router2>... <routerN>]"
    exit
} 


#child thread iteration proc
proc child_thread_iteration {router} {
    #child needs to call iter_thread_start as first action
    iter_thread_start
    set options [yaml::yaml2dict [iter_get_stdin]]
    #read in userpass data
    import_userpass [dict get $options "userpass_file"]
    # do stuff
    set commands_textblock [dict get $options commands_textblock]
    set returncode [catch {connectssh $router} output]
    if {$returncode == 0} {
        set returncode [catch {send_config $router $commands_textblock "set" "confirmed"} output]
    }
    iter_output $output
    #child thread proc needs to call iter_thread_finish as final action with return code as only arg
    iter_thread_finish $returncode
}

#optional stdin generator proc... this is suppled to concurrency::process_queue 
proc stdin_gen {router} {
    global argv
    #pass path to userpass file to child as "userpass_file"
    dict set options "userpass_file" [lindex $argv 0]
    #pass commands_textblock
    global commands_textblock
    dict set options "commands_textblock" $commands_textblock
    dict set options "router" $router
    return [yaml::dict2yaml $options]
}

concurrency::init "child_thread_iteration"

#read in userpass data
import_userpass [lindex $argv 0]

#start a log file based on yaml filename(.results.txt)
set filepath [lindex $argv 1]
init_logfile "$filepath.results.txt"

#create the working list of routers by matching rtr expressions against ewan config file list
h1 "Routers"
h2 "-- FINAL ROUTER LIST ------------------"
set routers_list [lrange $argv 2 end]
foreach router $routers_list {
    print " - $router"
}

#validate config with user and wait for confirmation
h1 "Config"
#read and generate configuration
set commands_textblock [gen::config_from_yaml $filepath]
print [string trim $commands_textblock]
nag_user "--\nReview Configuration...\n Press ENTER to Continue -- or -- Press CTRL-C to Cancel."

#execute commands on routers
test::start "Apply Configs to Routers"
#process queue concurrently, sending the return value of [stdin_gen $queue_item] to each thread instance
concurrency::process_queue $routers_list "stdin_gen"

foreach router $routers_list {
    test::subcase "Configure $router"
    test::analyze_textblock "send_config output for $router" [concurrency::get_result $router]
    set returncode [concurrency::get_returncode $router]
    test::assert "commit complete"
    test::assert "configuration check succeeds"
    test::end_analyze
    test::analyze_textblock "send_config returncode" $returncode
    test::assert "0"
    test::end_analyze
}
test::finish

