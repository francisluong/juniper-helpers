#!/usr/bin/env tclsh

if {[lindex $argv 0] ne "SLAVE"} {
  puts [clock format [clock seconds]]
  exec [info script] "SLAVE" &
  puts [clock format [clock seconds]]
  
} else {
  interp create waiter
  interp eval waiter {after 5000}
  interp eval waiter {return "returnvalue"}
}

