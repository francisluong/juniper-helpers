#!/usr/bin/tclsh

if {$argc < 1} {
    puts "Usage: pkg_mkIndex.tcl <path>"
    exit
}

set path [lindex $argv 0]
pkg_mkIndex $path
puts [exec cat $path/pkgIndex.tcl]
