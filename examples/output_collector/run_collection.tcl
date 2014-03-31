#!/usr/bin/env tclsh

package require JuniperConnect
package require yaml
package require output


proc verify_options {options_dict} {
  set pass 1
  foreach key [list "path_main" "path_templates" "output_folder"] {
    set filepath [file normalize [dict get $options_dict $key]]
    if {([file isdirectory $filepath] && [file writable $filepath])} {
      #good
    } else {
      puts stderr "Filepath $filepath doesn't exist or not writable"
    }
  }
  if {!$pass} {
    exit
  }
}

set collector_dir [file dir $argv0]
set options_dict [yaml::yaml2dict [read_file "${collector_dir}/etc/config.yml"]]
output::pdict $options_dict
verify_options $options_dict

exit
init_logfile "/var/tmp/results"
#usage
if {$argc < 2} {
  puts "Usage: [info script] <router_address> <path_to_userpass_file>"
  exit
} 
