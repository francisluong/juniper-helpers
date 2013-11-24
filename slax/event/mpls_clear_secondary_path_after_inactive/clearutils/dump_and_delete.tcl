#!/usr/local/bin/tclsh

source ~/bin/library_main.tcl

set routername "root@er10-wdc1"
router_show_string $routername "
  file list /var/tmp/*clear* 
"
set output [output_stripped]
puts output
foreach this_file [lrange [nsplit $output] 1 end] {
  lappend commands_list "file show $this_file"
  lappend delete_list "file delete $this_file"
}
router_show $routername $commands_list
router_show $routername $delete_list

