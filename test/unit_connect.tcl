#!/usr/bin/tclsh

package require JuniperConnect
set router 192.168.1.31
juniperconnect::connectssh $router lab lab123
set commands_list [list "sh ver" "sh system uptime"]
juniperconnect::send_commands $router $commands_list
set commands_textblock "
  show chassis hardware
  show version
"
juniperconnect::send_textblock $router $commands_textblock
juniperconnect::disconnectssh $router
puts end
