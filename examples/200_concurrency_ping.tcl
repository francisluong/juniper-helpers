#!/usr/bin/env tclsh

package require test
package require concurrency
package require yaml

#set concurrency::debug 1

#usage
if {$argc < 1} {
    puts "Usage: [info script] <targetAddress1> .. <targetAddressN>"
    exit
} 

#child thread proc
proc run_iteration {ping_target} {
    #child needs to call iter_thread_start as first action
    iter_thread_start
    set options [yaml::yaml2dict [iter_get_stdin]]
    set count [dict get $options "count"]
    test::subcase "Ping $ping_target"
    set returncode [ catch {exec ping -c $count $ping_target} output ]
    test::analyze_textblock "Ping output for $ping_target" $output
    test::assert "0% packet loss"
    test::end_analyze
    #child thread proc needs to call iter_thread_finish as final action with return code as only arg
    iter_thread_finish $returncode
}

#optional stdin generator proc... this is suppled to concurrency::process_queue 
proc stdin_gen {ping_target} {
    global count
    dict set options "count" $count
    incr count 2
    return [yaml::dict2yaml $options]
}
#first value of count
set count 5

#need to call concurrency::init and provide the procname for the child thread
concurrency::init "run_iteration"
#...and make sure not to init the main log file until after concurrency::init
init_logfile "/var/tmp/results"


#main test instance
#process queue concurrently, sending the return value of [stdin_gen $queue_item] to each thread instance
concurrency::process_queue $argv "stdin_gen"
concurrency::report_detail
concurrency::report_pass_fail

