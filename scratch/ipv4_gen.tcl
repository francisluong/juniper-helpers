#!/usr/bin/env tclsh8.5

package require gen
package require homeless

puts [gen::ipv4 "10.0.0.1" 10]
set k [gen::ipv4 "192.0.0.0" 1024 0.0.1.0]
puts "[lindex $k 0], [lindex $k 10], [lindex $k end]"
