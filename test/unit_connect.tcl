#!/usr/bin/env tclsh

set auto_path [linsert $auto_path 0 "/home/fluong/code/juniper-helpers"]
package require JuniperConnect
package require output

init_logfile "/var/tmp/results"
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
print [blockanchor [lineanchor $output]]
h2 "split it into two blocks using empty line"
foreach block [textproc::split_on_empty_line $output] {
  print [blockanchor $block]
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
print [blockanchor $output]
foreach expr [list "Virtual" "virtual" "^Virtual" "^FPC"] {
  h2 "linematch for $expr"
  print "(expression: '$expr')"
  print [blockanchor [textproc::linematch $expr $juniperconnect::output]]
}
set textblocks [textproc::split_on_empty_line $juniperconnect::output]
lassign $textblocks first second
h2 "First Command and Output"
print $first


h2 "Second Command and Output"
print $second

foreach expr [list "(R1|Model)"] {
  h2 "inverse linematch for $expr"  
  print "(expression: '$expr')"
  print [blockanchor [textproc::linematch_inverse $expr $second]]
}


print {}
print end
