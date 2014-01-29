#!/usr/bin/env tclsh

set auto_path [linsert $auto_path 0 "/home/fluong/code/juniper-helpers"]
package require test
package require tdom

init_logfile "/var/tmp/results"
#usage
if {$argc < 2} {
  puts "Usage: [info script] <router_address> <path_to_userpass_file>"
  exit
} 
set router [lindex $argv 0]
import_userpass [lindex $argv 1]
puts "r_username: '$juniperconnect::r_username'"

test::start "connect"
juniperconnect::connectssh $router "netconf"
set hello [juniperconnect::get_hello $router]
puts $hello
#parse xml and get session id
set root [dom parse $hello]
set node [$root selectNodes "hello/session-id/text()"]
h2 "parse session id"
puts [$node data]
puts "endend"
