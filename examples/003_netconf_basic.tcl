#!/usr/bin/env tclsh

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

test::start "Verify Chassis is of type Firefly or MX960"

  test::subcase "Verify Chassis matches 'FIREFLY' or 'MX'"
  test::analyze_netconf $router [build_rpc $router "get-chassis-inventory"]
  test::xassert "chassis-inventory"
  test::xassert "chassis-inventory/chassis/chassis-module\[name='FPC 0']/chassis-sub-module"
  test::xassert "chassis-inventory/chassis/chassis-module\[name='FPC 0']/chassis-sub-module/name/text()" regexp "PIC 0"
  test::xassert "chassis-inventory/chassis/description/text()" regexp "(FIREFLY|MX).*"
  test::xassert "chassis-inventory/chassis/chassis-module" count >= 5
  test::end_analyze

  test::subcase "Verify Version is JUNOS"
  test::analyze_netconf $router [build_rpc $router "get-software-information"]
  test::xassert "software-information/package-information\[name='junos']/comment/text()" regexp "JUNOS Software Release"
  test::end_analyze

test::finish
