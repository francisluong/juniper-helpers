#!/usr/local/bin/tclsh

source ~/bin/library_main.tcl

set localpath "/home/fluong/bin/slax"
foreach routername [list "root@er10-wdc1-re1" "root@er10-wdc1-re0"] {
  set filepath "clear_secondary_path_after_inactive.slax"
  set destfolder "/var/db/scripts/event/"

  rtrscpput $routername "$localpath/$filepath" $destfolder
}
foreach routername [list "root@er10-wdc1-re1" "root@er10-wdc1-re0"] {
  router_show_string $routername "file list det $destfolder/$filepath"
}

