package provide homeless 1.0
package require Tcl 8.5
package require Expect

namespace eval ::homeless {
    #homeless procs... I'll find a place for them later... all get imported into root namespace (I know...)
    namespace export *

    proc read_file {file_name_and_path} {
     ###########################################
     # abstract: reads in the contents of a file and returns a string
     #
     # inputs:
     # - file_name_and_path - text string, fully qualified path to a file
     # returns:
     # - string containing the contents of the file
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

    proc prompt_user {prompt_text timeout_seconds} {
        #prompt_text is presented to stdout
        #timeout is in seconds... -1 means wait forever
        send_user -- "$prompt_text"
        set result -1
        #timeout is in seconds... -1 means wait forever
        set timeout $timeout_seconds
        expect_user {
             -re "(.*)\n" { 
                 set result 1
                 set result $expect_out(1,string) 
             }
             timeout {}
        }
        return $result
    }

    proc nag_user {prompt} {
        #pause
        set done 0
        set timeout 30
        set iteration_limit 1000
        set this_iteration 0
        while {!$done && $this_iteration < $iteration_limit} {
            incr this_iteration
            ding 2
            set result [[namespace current]::prompt_user $prompt $timeout]
            set prompt "."
            if {$result != -1} {set done 1}
        }
    }

    proc ding {count} {
        set ding "\007"
        if {$count==0} {
            puts $ding
        } else {
            for {set x 0} {$x<$count} {incr x} {
                puts -nonewline $ding; flush stdout
                after 300
            }
        }
    }

    proc list_filter_distinct {input_list {keep_order "sort"}} {
      ###########################################
      # abstract: takes a list and returns a list without any duplicates
      ###########################################
        set result {}
        if {$keep_order eq "sort"} {
            #faster if we sort
            set last "-1-1-1-1-1"
            foreach element [lsort $input_list] {
                if {$element ne $last} {
                    lappend result $element
                }
                set last $element
            }
        } else {
            #more searches to keep the order
            foreach element $input_list {
                if {[lsearch -exact $result $element]==-1} {
                    lappend result $element
                }
            }
        }
        return $result
    }

}
namespace import homeless::*
