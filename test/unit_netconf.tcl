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

test::start "netconf connect"

  juniperconnect::connectssh $router "netconf"
  set hello [juniperconnect::get_hello $router]
  #parse xml and get session id
  set root [dom parse $hello]
  set node [$root selectNodes "hello/session-id/text()"]

  h2 "parse session id"
  set session_id [$node data]
  test::analyze_textblock "Netconf Hello Contents" $hello
  print " - Acquired Session ID: $session_id"
  test::assert $session_id
  test::end_analyze

  h2 "craft a request for get-chassis-inventory detail"
  set rpc [dom createDocument "rpc"]
  set root [$rpc documentElement]
  set get_inv [$rpc createElement "get-chassis-inventory"]
  $root appendChild $get_inv
  $get_inv appendChild [$rpc createElement "detail"]
  print [$root asXML]

  h2 "netconf inventory from router"
  send_rpc $router [$rpc asXML]

test::finish
