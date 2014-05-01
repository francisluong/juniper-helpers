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

test::start "XML Stuff"

    test::subcase "Get Interfaces Subtree of Configuration"
    test::analyze_netconf $router [build_rpc "get-configuration"]
    test::xml_scope "configuration/interfaces"
    test::xassert "/interfaces/interface/unit\[name='0']/family/inet/address/name"
    test::end_analyze

test::finish
