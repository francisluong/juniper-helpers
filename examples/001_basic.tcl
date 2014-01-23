#!/usr/bin/env tclsh

set auto_path [linsert $auto_path 0 "/home/fluong/code/juniper-helpers"]
package require JuniperConnect
package require output

init_logfile "/var/tmp/results"
set line [string repeat - 50]
set router 192.168.1.31

h1 "Verify Chassis is of type JunosV Firefly"

h2 "Connect, Issue Commands, and Process Output"
connectssh $router lab lab123
set commands_textblock "
  show chassis hardware
  show version
"
set output [send_textblock $router $commands_textblock]
print $output

h2 "Verify Chassis matches 'JUNOSV-FIREFLY'"
set expression "Chassis .* JUNOSV-FIREFLY"
set grep_result [grep_output $expression]
if {$grep_result ne ""} {
  print "Router Chassis matches expression: '$expression'"
} else {
  print "No Match: '$expression'" 
}
print $grep_result

