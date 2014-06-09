#!/usr/bin/env tclsh

package require gen
package require test
package require concurrency
package require yaml

#set concurrency::debug 1

#usage
if {$argc < 3} {
    puts stderr "Usage: [info script] <userpass_file> <yaml_config_gen_file> <router1> \[<router2>... <routerN>] \[test\]"
    exit
} 


#child thread iteration proc
proc child_thread_iteration {router} {
    #child needs to call iter_thread_start as first action
    iter_thread_start
    set options [concurrency::iter_get_stdin_dict]
    set test [dict get $options test]
    if {$test} {
        set confirmed_simulate "simulate"
    } else {
        set confirmed_simulate "confirmed"
    }
    # do stuff
    set commands_textblock [dict get $options commands_textblock]
    test::subcase "Configure $router"
    test::apply_config $router $commands_textblock "set" $confirmed_simulate
    #check if show | compare produced zero lines
    set expression "Count: 0 lines"
    set grep_result [textproc::grep $expression $test::analyze_buffer]
    if {$grep_result ne ""} {
        set show_compare_zero 1
    } else {
        set show_compare_zero 0
    }
    #verify configuration check if not empty config
    if {!$show_compare_zero} {
        test::assert "configuration check succeeds"
    }
    #verify error is not seen
    test::assert "(error|fail)" "not present"
    if {!$test} {
        test::assert "commit complete"
    }
    set pass [test::end_analyze]
    if {$pass} {
        set returncode 0
    } else {
        set returncode 1
    }
    #child thread proc needs to call iter_thread_finish as final action with return code as only arg
    iter_thread_finish $returncode
}

#optional stdin generator proc... this is suppled to concurrency::process_queue 
proc stdin_gen {router} {
    global argv test
    #pass commands_textblock
    global commands_textblock
    dict set options "commands_textblock" $commands_textblock
    dict set options "router" $router
    dict set options "test" $test
    return $options
}

concurrency::init "child_thread_iteration"

#read in userpass data
import_userpass [lindex $argv 0]

#if last argv item is "test" then set test to 1 else 0
if {[string match -nocase "test" [lindex $argv end]]} {
    set test 1
    set argv [lrange $argv 0 end-1]
} else {
    set test 0
}

#start a log file based on yaml filename(.results.txt)
set filepath [lindex $argv 1]
init_logfile "/var/tmp/[file tail $argv0].results.txt"

#create the working list of routers by matching rtr expressions against ewan config file list
h1 "Routers"
h2 "-- FINAL ROUTER LIST ------------------"
set routers_list [lrange $argv 2 end]
foreach router $routers_list {
    print " - $router"
}

#validate config with user and wait for confirmation
h1 "Config"
if {$test} {
    output::h1 "Config (Test Run -- COMMIT CHECK ONLY)"
} else {
    output::h1 "Config"
}
#read and generate configuration
set commands_textblock [gen::config_from_yaml $filepath]
output::h2 "Processed config"
print [string trim $commands_textblock]
nag_user "--\nReview Configuration...\n Press ENTER to Continue -- or -- Press CTRL-C to Cancel."

#execute commands on routers
test::start "Apply Configs to Routers"
#process queue concurrently, sending the return value of [stdin_gen $queue_item] to each thread instance
h1 "Process Queue"
concurrency::process_queue $routers_list "stdin_gen"

h1 "Report Results"
concurrency::report_detail
concurrency::report_pass_fail
