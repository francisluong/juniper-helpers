#!/usr/bin/env tclsh

package require test
package require concurrency

#usage
if {$argc < 1} {
    puts "Usage: [info script] <targetAddress1> .. <targetAddressN>"
    exit
} 

proc run_iteration {ping_target} {
    iter_thread_start
    set returncode [ catch {exec ping -c 5 $ping_target} output ]
    print $output
    iter_thread_finish $returncode
    return $returncode
}

concurrency::init "run_iteration"
init_logfile "/var/tmp/results"
test::start "Ping All Targets"
concurrency::process_queue $argv

foreach queue_item $argv {
    test::subcase "Ping $queue_item"
    test::analyze_textblock "Ping output for $queue_item" [concurrency::get_result $queue_item]
    test::assert "0% packet loss"
    test::end_analyze
}

test::finish
