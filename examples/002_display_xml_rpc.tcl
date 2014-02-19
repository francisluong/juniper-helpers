#!/usr/bin/env tclsh

package require JuniperConnect

#usage
if {$argc < 2} {
  puts "Usage: [info script] <router_address> <path_to_userpass_file> <command>"
  exit
} 
set router [lindex $argv 0]
import_userpass [lindex $argv 1]
set command [join [lrange $argv 2 end]]

connectssh $router
puts [send_textblock $router "$command | display xml rpc"]
disconnectssh $router
