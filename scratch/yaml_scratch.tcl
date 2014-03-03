#!/usr/bin/env tclsh8.5

proc read_file {file_name_and_path} {
 ###########################################
 # abstract: reads in the contents of a file and returns a string
 #
 # inputs:
 #    - file_name_and_path - text string, fully qualified path to a file
 # returns:
 #    - string containing the contents of the file
 ###########################################
  set procname "proc [lindex [info level 0] 0]"
  if {![file exists $file_name_and_path]} {
    return -code error "$procname: ERROR -- file not found: $file_name_and_path"
  }
  set fl [open $file_name_and_path]
  set file_contents [read $fl]
  close $fl
  return $file_contents
}


puts [package require yaml]
set filepath "/home/fluong/juniper-helpers/scratch/test.yml"
set yaml_in [yaml::yaml2dict [read_file $filepath]]
puts $yaml_in
puts "SRLGID: [dict get $yaml_in simple_substitutions SRLGID]"
puts "keys: [dict keys $yaml_in]"
