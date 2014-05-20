
###############################################################################
# <!--------------- Concurrency Queue -------------->
###############################################################################
#
# Abstract
# ================
# The idea here is that we are able to run multiple expect sessions simultaneously
# so that we can run the same commands over a number of routers more quickly.
#
# TCL doesn't give us a good way to do this.
# Instead, we rely on multiple instances of scripts, managed by a master script
#
# This library will be intended to make it easy to write a script which doubles 
# as the master script and the iteration script.
#
# Setting Up
# ==========
# to begin, we would need to define a thread_iteration proc and identify that to 
# the library using a call to proc "XXX" with the name of the thread_iteration
# proc as its argument
#
# Main
# ====
#
# call concurrency::init before doing anything else. it will run thread_iteration
#   if certain text is passed through argv
#
# Master Script
# ================
#
# the master script will work through a list of items, called "input_queue"
# this will be the only input into the thread_iteration script
#
# when starting a thread_iteration, it will spawn process as background process
# until there are a number running equal to "max_threads"
#
# Thread_Iteration Proc
# =====================
#
# this is technically something a user of this package would write... 
# but there are some rules
# 
# 1. proc should call "iter_thread_start" before doing anything else
# 2. always use iter_output rather than puts when you need output to be logged
# 99. proc should call "iter_thread_finish" when it's done with everything
# 
# Stdin Gen Proc (optional)
# =================================
# this proc will take queue_item as an argument and return a dict
# which will be serialized inot yaml and
# presented to stdin for the child thread iteration proc
#

package provide concurrency 1.0
package require base32
package require homeless
package require countdown
package require output

namespace eval concurrency {
    namespace export iter_thread_start iter_thread_finish iter_get_stdin_dict iter_output

    variable max_threads 5
    variable wait_seconds 2
    variable input_queue {}
    variable current_queue {}
    variable finished_queue {}
    variable thread_iteration_procname {}
    variable iteration_match_text "RUN_THREAD_ITERATION"
    variable iteration_argv_index 0
    #long form results are stored here
    variable results_array
    array unset results_array
    array set results_array {}
    #result codes are stored here
    variable returncode_array
    array unset returncode_array
    array set returncode_array {}

    #debug
    variable debug 0

    #these are used if it is a thread_iteration
    variable tmp_folder "/var/tmp"
    variable is_thread_iteration 0
    variable queue_item {}
    variable stdin_text {}
    variable options_dict {}
    variable tcl_file {}
    variable output_filename {}
    variable output_filepath {}

    #this is used to generate global variables to yaml --> thread stdin
    #   - send userpass database and username
    #   - send original argv0
    #   - use concurrency::data to add arbitrary key/value pairs
    variable serial_data_dict {}

    proc init {thread_iteration_procname} {
        # call this early in your application... 
        # it will kick off thread_iteration proc if applicable
        # otherwise we assume it's the main queue handler
        global argc argv   
        variable iteration_match_text
        variable iteration_argv_index
        #if this is an iteration, run it and exit
        if {[lindex $argv $iteration_argv_index] eq $iteration_match_text} {
            #read stdin and parse yaml into options_dict
            variable stdin_text [read stdin]
            variable options_dict [yaml::yaml2dict $stdin_text]
            #read in userpass data if keys exist in $options_dict
            if {[dict exists $options_dict "concurrency" "userpass_dict"] && [info exists juniperconnect::r_db]} {
                array set juniperconnect::r_db [dict get $options_dict "concurrency" "userpass_dict"]
                set username [dict get $options_dict "concurrency" "userpass_username"]
                if {$username ne ""} {
                    juniperconnect::change_rdb_user $username
                }
            }
            #setup some variables
            variable is_thread_iteration 1
            variable queue_item [lindex $argv 1]
            variable output_filename [dict get $options_dict "concurrency" "output_filename"]
            variable output_filepath [dict get $options_dict "concurrency" "output_filepath"]
            puts "output_filename: $output_filename"
            puts "output_filepath: $output_filepath"
            #call thread_iteration and exit 
            set catch_result [catch {$thread_iteration_procname $queue_item} catch_output]
            if {$catch_result > 0} {
                [namespace current]::iter_output $catch_output
                [namespace current]::iter_thread_finish $catch_result
            }
            exit
        # else - not a thread!!!
        } else {
            #initialize things
            variable input_queue
            variable current_queue
            variable finished_queue
            variable serial_data_dict
            set input_queue {}
            set current_queue {}
            set finished_queue {}
            set serial_data_dict {}
            #probably won't need this
            set [namespace current]::thread_iteration_procname $thread_iteration_procname
        }
    }

    proc process_queue {input_queue {stdin_gen_procname ""} {tcl_script_filepath "default"}} {
        # call this when we are all setup and we want to start the run
        #initialize
        set concurrency::input_queue {}
        set concurrency::current_queue {}
        set concurrency::finished_queue {}
        set concurrency::input_queue $input_queue
        set wait_seconds 1
        puts "Queue Start"
        #loop until we are done with the queue
        set queue_empty [[namespace current]::_queue_is_empty]
        while {!$queue_empty} {
            #start a new thread if we can, if not... returns -1
            set queue_item [[namespace current]::_next_item]
            while {$queue_item != -1} {
                #started a new thread... try to start more until we get a return of -1
                [namespace current]::_main_thread_start $queue_item $stdin_gen_procname $tcl_script_filepath
                set queue_item [[namespace current]::_next_item]
            }
            #perform wait unless complete
            if {!$queue_empty} {
                puts -nonewline "  "
                after [expr $wait_seconds * 1000]
            }
            set wait_seconds $concurrency::wait_seconds
            #finish each item that is ready
            foreach queue_item $concurrency::current_queue {
                _main_thread_finish ${queue_item}
            }
            #check to see if we are done with the queue
            set queue_empty [[namespace current]::_queue_is_empty]
        }
        puts "Queue Finish"
        #how do I pass data back to the guy who called process_queue?
    }

    proc report_detail {{print_to_stdout "1"}} {
        variable finished_queue
        set old_output_quiet_stdout $output::quiet_stdout
        if {!$print_to_stdout} {
            set output::quiet_stdout 1
        }
        #print test results
        foreach queue_item $finished_queue {
            set this_result [[namespace current]::get_result $queue_item]
            output::h2 "Thread Output: $queue_item"
            output::print $this_result
        }
        #print closing HR
        output::print "\n[output::hr "="]" 0
        set output::quiet_stdout $old_output_quiet_stdout
    }

    proc report_pass_fail {{print_to_stdout "1"}} {
        variable finished_queue
        set old_output_quiet_stdout $output::quiet_stdout
        if {!$print_to_stdout} {
            set output::quiet_stdout 1
        }
        #print test result codes
        set outparts {}
        set overall_pass "PASS"
        foreach queue_item $finished_queue {
            set this_resultcode [[namespace current]::get_returncode $queue_item]
            set outcome "PASS"
            if {$this_resultcode > 0} {
                set outcome "FAIL"
                set overall_pass "FAIL"
            }
            lappend outparts "** $queue_item --> $outcome"
        }
        lappend outparts "Summary Test Result --> $overall_pass"
        output::h2 "Test Result Summary --> $overall_pass"
        output::print [textproc::njoin $outparts]
        #print closing HR
        output::print "\n[output::hr "="]" 0
        set output::quiet_stdout $old_output_quiet_stdout
    }

    proc iter_thread_start {} {
        variable queue_item
        variable output_filepath
        variable output_filename
        if {$concurrency::debug eq 1} {
            puts "iter_thread_start: outfile: $output_filepath"
        }
        #initialize logfile
        output::init_logfile $output_filepath
        output::print "$output_filename - START"
    }

    proc iter_thread_finish {returncode} {
        variable queue_item
        #output flag to indicate thread_iteration is complete
        variable output_filename
        [namespace current]::iter_output "\n$output_filename - RETURNCODE: $returncode"
        if {$concurrency::debug eq 1} {
            variable output_filepath
            puts "\niter_thread_finish: outfile: $output_filepath"
        }
        #exit script execution
        exit
    }

    proc data {key value} {
        variable serial_data_dict
        set reserved_values_list [list "concurrency"]
        if {[lsearch -exact $reserved_values_list $key] == -1} {
            dict set serial_data_dict $key $value
        } else {
            return -code error "[namespace current]::data ERROR: key '$key' is in reserved key list"
        }
    }

    proc iter_get_stdin_dict {} {
        variable options_dict
        return $options_dict
    }

    proc iter_output {outtext {indent_space_count "0"}} {
        output::print $outtext $indent_space_count
    }

    proc get_result {queue_item} {
        variable results_array
        return $results_array($queue_item)
    }

    proc get_returncode {queue_item} {
        variable returncode_array
        return $returncode_array($queue_item)
    }

    #======================
    # INTERNAL PROCS
    #======================

    proc _next_item {} {
        #get next item or return -1
        #return -1 if no sessions are available
        variable max_threads
        variable current_queue
        variable input_queue
        set this_item "-1"
        set current_sessions [llength $current_queue]
        if {[llength $input_queue] != 0 && ($current_sessions < $max_threads)} {
            #dequeue
            set this_item [lindex $input_queue 0]
            set input_queue [lrange $input_queue 1 end]
            #add to current_list
            lappend current_queue $this_item
        }
        return $this_item
    }

    proc _main_thread_start {queue_item {stdin_gen_procname ""} {tcl_script_filepath "default"}} {
        variable debug
        #runfile - path to thread script
        #queue_item - the text of the concurrency queue item
        set outfile [[namespace current]::_output_filepath $queue_item]
        puts "  Start: $queue_item -- $outfile"
        variable iteration_match_text
        file delete -force $outfile
        variable serial_data_dict
        set options $serial_data_dict
        if {[info exists juniperconnect::r_db]} {
            dict set options "concurrency" "userpass_dict" [array get juniperconnect::r_db]
            dict set options "concurrency" "userpass_username"  $juniperconnect::r_username
        }
        dict set options "concurrency" "output_filename" [concurrency::_output_filename $queue_item]
        dict set options "concurrency" "output_filepath" [concurrency::_output_filepath $queue_item]
        dict set options "concurrency" "queue_item" $queue_item
        if {$stdin_gen_procname ne ""} {
            set generated_dict [eval $stdin_gen_procname $queue_item]
            if {$debug} {
                output::pdict options
                output::pdict generated_dict
            }
            set text_to_stdin [yaml::dict2yaml [dict merge $options $generated_dict]]
        } else {
            set text_to_stdin [yaml::dict2yaml $options]
        }
        if {$debug} {
            output::h2 "YAML to stdin"
            output::print $text_to_stdin
        }
        if {$tcl_script_filepath eq "default"} {
            set tcl_script_filepath [info script]
        }
        if {!$debug} {
            exec $tcl_script_filepath $iteration_match_text $queue_item $outfile << $text_to_stdin >& /dev/null &
        } else {
            #DO NOT background execute
            output::h2 "_main_thread_start $queue_item (debug/not-concurrent)"
            puts [exec $tcl_script_filepath $iteration_match_text $queue_item $outfile << $text_to_stdin ]
        }
    }

    proc _main_thread_finish {queue_item} {
        set outfile [[namespace current]::_output_filepath $queue_item]
        set ofilename [[namespace current]::_output_filename $queue_item]
        #read file
        if {[file readable $outfile]} {
            set filetext [string trim [read_file $outfile]]
        } else {
            set filetext ""
        }
        #get last line
        set last_line [lindex [nsplit $filetext] end]
        #if last line begins with $ofilename, thread_iteration is complete
        if { [string match "*$ofilename - RETURNCODE*" $last_line] } {
            set finished 1
            set index [lsearch -exact $concurrency::current_queue $queue_item]
            if {$index != -1} {
                #match found
                #delete queue_item from current_list
                set concurrency::current_queue [lreplace $concurrency::current_queue $index $index]
                #add queue_item to finished_list
                lappend concurrency::finished_queue $queue_item
                variable results_array
                variable returncode_array
                set results_array($queue_item) $filetext
                set returncode_array($queue_item) [lindex $last_line end]
                if {!$concurrency::debug} {
                    file delete -force $outfile
                }
            } else {
                #match not found
                return -code error "concurrency::thread_finish: dequeuing problem: $queue_item not found"
            }
        } else {
            set finished 0
        }
        return $finished
    }

    proc _queue_is_empty {} {
        set input_empty 0
        set current_empty 0
        variable input_queue
        variable current_queue
        variable finished_queue
        set ilen [llength $input_queue]
        set clen [llength $current_queue]
        set flen [llength $finished_queue]
        puts "  Queues (in/curr/fin): $ilen/$clen/$flen"
        if {$clen > 0} {
            puts "    >> current: $current_queue"
        }
        if {$ilen == 0} {
            set input_empty 1
        }
        if {$clen == 0} {
            set current_empty 1
        }
        if {$input_empty && $current_empty} {
            return 1
        } else {
            return 0
        }
    }

    proc _output_filename {queue_item} {
        global argv0
        return "[file tail $argv0].[string trimright [base32::encode $queue_item] "="]"
    }

    proc _output_filepath {queue_item} {
        global tcl_platform
        #set format_string "%G-%m%d"
        #set today [clock format [clock seconds] -format $format_string]
        set ofilename [[namespace current]::_output_filename $queue_item]
        if {[info exists tcl_platform(user)]} {
            set user $tcl_platform(user)
        } else {
            set user ""
        }
        return "$concurrency::tmp_folder/$user.$ofilename.txt"
        #return "$concurrency::tmp_folder/$today.$ofilename.$user.txt"
    }

}
namespace import concurrency::*
