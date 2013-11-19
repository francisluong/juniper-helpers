#!/usr/local/bin/tclsh

source ~/bin/library_main.tcl

set routername "er10-wdc1"
set interface "ae11"
router_show_string $routername "
  configure private
  set interface $interface disable
  commit and-quit
"
countdown_sec 90 3
router_show_string $routername "
  request mpls lsp adjust-autobandwidth 
  configure private
  delete interface $interface disable
  commit and-quit
"
countdown_sec 90 3
router_show_string $routername "
  clear mpls lsp optimize 
"
countdown_sec 90 3

