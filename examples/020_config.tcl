#!/usr/bin/env tclsh

package require JuniperConnect
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

connectssh $router

#1
set config_textblock "
    annotate system 020_config.tcl
    annotate interfaces 020_config.tcl
"
send_config $router $config_textblock set

#2
set config_textblock "
interfaces lo0 {
    description 020_config.tcl;
}
"
send_config $router $config_textblock merge

#3
set config_textblock "
    annotate system ''
    annotate interfaces ''
    delete interfaces lo0 description
"
send_config $router $config_textblock cli confirmed
