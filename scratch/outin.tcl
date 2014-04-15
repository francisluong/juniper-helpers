#!/usr/bin/env tclsh

package require yaml
dict set out "key1" "value1"
dict set out "key2" "
    value2
    value2
    value2
"
puts [exec ./stdin.tcl << [yaml::dict2yaml $out]]
