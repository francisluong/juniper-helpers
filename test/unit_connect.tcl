#!/usr/bin/env tclsh

set auto_path [linsert $auto_path 0 "/home/fluong/code/juniper-helpers"]
package require JuniperConnect
package require output


set line [string repeat - 50]
set router 192.168.1.31

h1 "connect, issue 2 commands as a list, and disconnect"
h2 "connect"
juniperconnect::connectssh $router lab lab123
h2 "issue commands"
set commands_list [list "sh ver" "sh system uptime"]
set output [juniperconnect::send_commands $router $commands_list]
h2 "disconnect"
juniperconnect::disconnectssh $router
h2 "captured output"
puts [indent [blockanchor [lineanchor $output]] 2]
h2 "split it into two blocks using empty line"
foreach block [textproc::split_on_empty_line $output] {
  puts [indent [blockanchor $block] 2]
}

h1 "connect, issue 2 commands as a textblock, and grep the output"
h2 "connect"
juniperconnect::connectssh $router lab lab123
h2 "send commands"
set commands_textblock "
  show chassis hardware
  show version
"
set output [juniperconnect::send_textblock $router $commands_textblock]
juniperconnect::disconnectssh $router
h2 "disconnect"
juniperconnect::disconnectssh $router
h2 "captured output"
puts [indent [blockanchor $output] 2]
foreach expr [list "Virtual" "^Virtual" "^FPC"] {
  h2 "linematch for $expr"
  puts "(expression: '$expr')"
  puts [indent [blockanchor [textproc::linematch $expr $juniperconnect::output]] 2]
}
puts end
