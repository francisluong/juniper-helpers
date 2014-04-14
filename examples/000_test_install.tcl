#!/usr/bin/env tclsh

puts "Tcl Package Path on your computer:"
foreach item $tcl_pkgPath {
    puts " - $item"
}
puts "\nAttempting to access package JuniperConnect"
if { [catch {package require JuniperConnect}] > 0 } {
    puts stderr " - Unable to verify successful installation of Juniper-Helpers"
    puts stderr " - Juniper Helpers needs to be a subfolder of a package path or you will need to set the environment variable TCLLIBPATH"
    puts stderr "      TCLLIBPATH=/path/to/juniper-helpers"
    exit
} else {
    puts " - SUCCESS!\n"
}

package require output
package require homeless
set library_path [file dir [lindex [package ifneeded JuniperConnect 1.0] end]]
h1 "LIBRARY PATH: $library_path"

h2 "tcllib"
if {[catch {package require yaml 0.3.6} yaml_version] > 0} {
    puts stderr "Unable to verify installation of TCL Standard Library: tcllib"
    exit
} else {
    print "Confirmed installation of TCL Standard Library: tcllib//YAML: $yaml_version"
}

h2 "tdom"
if {[catch {package require tdom} tdom_version] > 0} {
    puts stderr "Unable to verify installation of TCL Document Object Model: tdom"
    exit
} else {
    print "Confirmed installation of TCL Document Object Model: tdom $tdom_version"
}

h2 "ssh"
set return_code [catch {exec ssh -V} output]
if {![string match "OpenSSH*" $output]} {
    puts stderr "Unable to verify installation of OpenSSH"
    exit
} else {
    print "Confirmed OpenSSH: $output"
}

h2 "Juniper-Helpers Library installation"
print "Confirmed Juniper-Helpers Library installation\n---"
set pkgindex "$library_path/pkgIndex.tcl"
set chan [open $pkgindex]
while {[gets $chan line] >= 0} {
    if {[string match "package *" $line]} {
        print "[lrange $line 2 3] \t==> found at [lindex [eval [lrange $line 0 3]] end]"
    }
}
close $chan

