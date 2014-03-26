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
send_config $router "
  annotate system 020_config.tcl
  annotate interfaces 020_config.tcl
" set
send_config $router "
snmp {
    description 020_config.tcl;
}
" merge
send_config $router "
  annotate system \"\"
  annotate interfaces \"\"
  delete snmp
"
