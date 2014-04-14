#!/usr/bin/env tclsh
set auto_path [linsert $auto_path 0 "/home/fluong/code/juniper-helpers"]
package require output
package require textproc

#tcl allows you to have variables with default values
proc blah {{text "default"}} {
    puts $text
}
blah
