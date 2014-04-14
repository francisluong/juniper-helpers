#!/usr/bin/tclsh

if {$argc < 1} {
    puts "Usage: add_to_tclshrc_auto_path.tcl <path>"
    exit
}

set path [file normalize [lindex $argv 0]]
if {![file isdirectory $path]} {
    puts stderr "Not a directory: $path"
    exit
}
set line "set auto_path \[linsert \$auto_path 0 $path\]"
puts $line
