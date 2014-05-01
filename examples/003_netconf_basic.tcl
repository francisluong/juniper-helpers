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
    test::analyze_netconf $router [build_rpc "get-chassis-inventory"]
    test::xassert "chassis-inventory"
    test::xassert "chassis-inventory/chassis/chassis-module\[name='FPC 0']/chassis-sub-module"
    test::xassert "chassis-inventory/chassis/chassis-module\[name='FPC 0']/chassis-sub-module\[name='PIC 0']"
    test::xassert "chassis-inventory/chassis/description/text()" regexp "(FIREFLY|MX).*"
    test::xassert "chassis-inventory/chassis/chassis-module" count >= 5
    test::end_analyze 

    test::subcase "Verify Version is JUNOS"
    test::analyze_netconf $router [build_rpc "get-software-information"]
    test::xassert "software-information/package-information\[1]/comment/text()" regexp "JUNOS"
    test::end_analyze "ascii"

    test::subcase "Verify Version is JUNOS (rpc reply from cli)"
    test::analyze_cli $router "show version | display xml" rpc
    test::xassert "software-information/package-information\[1]/comment/text()" regexp "JUNOS"
    test::end_analyze 

    test::subcase "Get Interfaces Subtree of Configuration - verify unit 0 family inet address present"
    test::analyze_netconf $router [build_rpc "get-configuration"]
    test::xml_scope "configuration/interfaces"
    test::xassert "/interfaces/interface/unit\[name='0']/family/inet/address/name"
    test::end_analyze

test::finish
