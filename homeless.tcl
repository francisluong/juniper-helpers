package provide homeless 1.0
package require Tcl 8.5

namespace eval ::homeless {
  #homeless procs... I'll find a place for them later... all get imported into root namespace (I know...)
  namespace export *

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



}
namespace import homeless::*
