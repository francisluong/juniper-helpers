#!/usr/bin/env tclsh

package require test
package require concurrency

#usage
if {$argc < 1} {
    puts "Usage: [info script] <targetAddress1> .. <targetAddressN>"
    exit
} 

#child thread proc
proc run_iteration {ping_target} {
    #child needs to call iter_thread_start as first action
    iter_thread_start
    set returncode [ catch {exec ping -c 5 $ping_target} output ]
    print $output
    #child thread proc needs to call iter_thread_finish as final action with return code as only arg
    iter_thread_finish $returncode
}

#need to call concurrency::init and provide the procname for the child thread
concurrency::init "run_iteration"
#...and make sure not to init the main log file until after concurrency::init
init_logfile "/var/tmp/results"
test::start "Ping All Targets"
#process queue concurrently
concurrency::process_queue $argv

#iterate through results outputs
foreach queue_item $argv {
    test::subcase "Ping $queue_item"
    test::analyze_textblock "Ping output for $queue_item" [concurrency::get_result $queue_item]
    test::assert "0% packet loss"
    test::end_analyze
}

test::finish
