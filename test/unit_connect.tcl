#!/usr/bin/tclsh

package require JuniperConnect
set router 192.168.1.31
set line [string repeat - 50]
juniperconnect::connectssh $router lab lab123
set commands_list [list "sh ver" "sh system uptime"]
set output [juniperconnect::send_commands $router $commands_list]
puts "\n>>$line\n$output\n$line<<"
set commands_textblock "
  show chassis hardware
  show version
"
set output [juniperconnect::send_textblock $router $commands_textblock]
puts "\n>>$line\n$output\n$line<<"
juniperconnect::disconnectssh $router
#
foreach expr [list "Virtual" "^Virtual" "^FPC"] {
puts "\n>>$line  
  (expression: 'expr')
[juniperconnect::grep $expr $juniperconnect::output]
$line<<"
}
puts end
