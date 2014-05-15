#!/usr/bin/env tclsh

package require test
package require concurrency
package require JuniperConnect

#you REALLY want to set this to 1 the first couple times to try to run anything
#set concurrency::debug 1

#child thread proc
proc run_iteration {router} {
    #child needs to call iter_thread_start as first action
    iter_thread_start
    set options [concurrency::iter_get_stdin_dict]
    output::pdict options
    set commands_list [dict get $options commands_list]
    connectssh $router
    set output [send_commands $router $commands_list]
    iter_output $output
    set returncode 0
    #child thread proc needs to call iter_thread_finish as final action with return code as only arg
    iter_thread_finish $returncode
}

#need to call concurrency::init and provide the procname for the child thread
concurrency::init "run_iteration"

#usage
if {$argc < 1} {
  puts "Usage: [info script] <path_to_userpass_file> router1 \[...routerN\]"
  exit
} 
set commands_textblock "
    show version
    show chassis hardware
"
#add commands to thread data
concurrency::data commands_list [split [string trim $commands_textblock] "\n"]

#basic output
import_userpass [lindex $argv 0]
set router_list [lrange $argv 1 end]
puts ">> Router List: $router_list"
set commands_clean [string trim $commands_textblock]
puts ">> Command: $commands_clean"


#main test instance
#process queue concurrently, sending the return value of [stdin_gen $queue_item] to each thread instance
h1 "Process Queue"
concurrency::process_queue $router_list
foreach router $router_list {
    output::h1 "$router: $commands_clean"
    output::print $concurrency::results_array($router)
}
