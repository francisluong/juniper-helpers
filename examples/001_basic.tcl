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
    test::analyze_output $router "
        show chassis hardware
        show version
    "
    test::assert "Chassis .* (FIREFLY|MX\[0-9]+)"
    test::assert "Chassis .* T640" "not present"
    test::assert "^FPC" "match and count" >= "1"
    test::end_analyze

    test::subcase "Limit Output then Verify interface ge-0/0/0.0 has protocol inet configured"
    test::analyze_cli $router "show interface"
    test::limit_scope "Logical interface ge-0/0/0.0" 
    test::assert "Protocol inet"
    test::end_analyze

test::finish
