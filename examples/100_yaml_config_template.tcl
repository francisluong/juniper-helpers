#!/usr/bin/env tclsh8.5

package require gen

if {$argc < 1} {
  puts "Usage: [info script] <path_to_YAML_file - e.g. 100_example.yml>"
  exit
} 
set filepath [lindex $argv 0]
puts [gen::config_from_yaml $filepath]
