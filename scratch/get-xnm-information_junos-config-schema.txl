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

    test::subcase "Get Config Schema"
    test::analyze_netconf $router [build_rpc "get-xnm-information/type='xml-schema',namespace='junos-configuration'"]
    test::end_analyze 


