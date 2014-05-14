#!/usr/bin/env tclsh

package require JuniperConnect
package require concurrency

#set concurrency::debug 1

#usage
if {$argc < 1} {
  puts "Usage: [info script] <path_to_userpass_file> router1 \[...routerN\]"
  exit
} 
import_userpass [lindex $argv 0]
set commands_textblock "
    show version
    show chassis hardware
"
set router_list [lrange $argv 1 end]
puts ">> Router List: $router_list"
set commands_clean [string trim $commands_textblock]
puts ">> Command: $commands_clean"


#juniperconnect::send_textblock_concurrent $router_list $command 1
array set results [juniperconnect::send_textblock_concurrent $router_list $commands_textblock]
foreach router $router_list {
    output::h1 "$router: $commands_clean"
    output::print $results($router)
}
