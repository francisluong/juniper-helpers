#!/usr/bin/env tclsh

if { [catch {package require JuniperConnect}] > 0 } {
  puts stderr "Unable to verify successful installation of Juniper-Helpers"
  exit
}
package require output
package require homeless
set library_path [file dir [lindex [package ifneeded JuniperConnect 1.0] end]]
h1 "LIBRARY PATH: $library_path"
h2 "Confirmed Juniper-Helpers Library installation"
set pkgindex "$library_path/pkgIndex.tcl"
set chan [open $pkgindex]
while {[gets $chan line] >= 0} {
  if {[string match "package *" $line]} {
    puts "    [lrange $line 2 3] \t==> found at [lindex [eval [lrange $line 0 3]] end]"
  }
}
close $chan
