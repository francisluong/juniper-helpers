#!/usr/bin/env tclsh

set auto_path [linsert $auto_path 0 "/home/fluong/code/juniper-helpers"]
package require test

init_logfile "/var/tmp/results"
#usage
if {$argc < 2} {
  puts "Usage: [info script] <router_address> <path_to_userpass_file>"
  exit
} 
set router [lindex $argv 0]
import_userpass [lindex $argv 1]
puts "r_username: '$juniperconnect::r_username'"

test::start "Verify Chassis is of type JunosV Firefly or MX960"

  test::subcase "Verify Chassis matches 'JUNOSV-FIREFLY'"
  test::analyze_output $router "
    show chassis hardware
    show version
  "
  test::assert "Chassis .* (JUNOSV-FIREFLY|MX\[0-9]+)"
  test::end_analyze

test::finish
