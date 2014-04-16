
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
# 2. always use print rather than puts when you need output to be logged
# 99. proc should call "iter_thread_finish" when it's done with everything
# 
# Stdin Gen Proc (optional)
# =================================
# this proc will take queue_item as an argument and return text to be 
# presented to stdin for the thread iteration proc
#

package provide concurrency 1.0
package require base32
package require output
package require homeless
package require countdown

namespace eval concurrency {
    namespace export iter_thread_start iter_thread_finish iter_get_stdin

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
    variable ofilename {}
    variable stdin_text {}

    proc init {thread_iteration_procname} {
        # call this early in your application... 
        # it will kick off thread_iteration proc if applicable
        # otherwise we assume it's the main queue handler
        global argc argv   
        variable iteration_match_text
        variable iteration_argv_index
        #if this is an iteration, run it and exit
        if {[lindex $argv $iteration_argv_index] eq $iteration_match_text} {
            #read stdin
            variable stdin_text [read stdin]
            #setup some variables
            variable is_thread_iteration 1
            variable queue_item [lindex $argv 1]
            variable ofilename [_output_filename $queue_item]
            #call thread_iteration and exit 
            $thread_iteration_procname $queue_item
            exit
        }
        #initialize things
        set concurrency::input_queue {}
        set concurrency::current_queue {}
        set concurrency::finished_queue {}
        #probably won't need this
        set concurrency::thread_iteration_procname $thread_iteration_procname
    }

    proc process_queue {input_queue {stdin_gen_procname ""}} {
        # call this when we are all setup and we want to start the run
        #initialize
        set concurrency::input_queue $input_queue
        set wait_seconds 1
        puts "Queue Start"
        #loop until we are done with the queue
        set queue_empty [_queue_is_empty]
        while {!$queue_empty} {
            #start a new thread if we can, if not... returns -1
            set queue_item [_next_item]
            while {$queue_item != -1} {
                #started a new thread... try to start more until we get a return of -1
                _main_thread_start $queue_item $stdin_gen_procname
                set queue_item [_next_item]
            }
            #perform wait unless complete
            if {!$queue_empty} {
                puts -nonewline "  "
                countdown::wait $wait_seconds 
                #after [expr $wait_seconds * 1000]
            }
            set wait_seconds $concurrency::wait_seconds
            #finish each item that is ready
            foreach queue_item $concurrency::current_queue {
                _main_thread_finish ${queue_item}
            }
            #check to see if we are done with the queue
            set queue_empty [_queue_is_empty]
        }
        puts "Queue Finish"
        #how do I pass data back to the guy who called process_queue?
    }

    proc iter_thread_start {} {
        variable queue_item
        set outfile [_output_filepath $queue_item]
        if {$concurrency::debug eq 1} {
            puts "iter_thread_start: outfile: $outfile"
        }
        #initialize logfile
        init_logfile $outfile
        set output::default_indent_count 0
    }

    proc iter_thread_finish {returncode} {
        variable queue_item
        set ofilename [_output_filename $queue_item]
        set outfile [_output_filepath $queue_item]
        #is a thread_iteration
        #output flag to indicate thread_iteration is complete
        output::print "\n$ofilename - RETURNCODE: $returncode"
        if {$concurrency::debug eq 1} {
            puts "\niter_thread_finish: outfile: $outfile"
            puts "output: logfile:............ $output::logfile"
        }
        exit
    }

    proc iter_get_stdin {} {
        variable stdin_text
        return $stdin_text
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

    proc _main_thread_start {queue_item {stdin_gen_procname ""}} {
        #runfile - path to thread script
        #queue_item - the text of the concurrency queue item
        puts "  Start: $queue_item -- [_output_filepath $queue_item]"
        variable iteration_match_text
        set outfile [_output_filepath $queue_item]
        file delete -force $outfile
        if {$stdin_gen_procname ne ""} {
            set text_to_stdin [eval $stdin_gen_procname $queue_item]
        } else {
            set text_to_stdin ""
        }
        if {$concurrency::debug eq 0} {
            exec [info script] $iteration_match_text $queue_item $outfile << $text_to_stdin >& /dev/null &
        } else {
            #DO NOT background execute
            h2 "_main_thread_start $queue_item (debug/not-concurrent)"
            puts [exec [info script] $iteration_match_text $queue_item $outfile << $text_to_stdin ]
        }
    }

    proc _main_thread_finish {queue_item} {
        set outfile [_output_filepath $queue_item]
        set ofilename [_output_filename $queue_item]
        #read file
        if {[file readable $outfile]} {
            set filetext [string trim [read_file $outfile]]
        } else {
            set filetext ""
        }
        #get last line
        set last_line [lindex [nsplit $filetext] end]
        #if last line begins with $ofilename, thread_iteration is complete
        if { [string match "*$ofilename*" $last_line] } {
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
        set format_string "%G-%m%d"
        set today [clock format [clock seconds] -format $format_string]
        set ofilename [_output_filename $queue_item]
        return "$concurrency::tmp_folder/$today.$ofilename.txt"
    }

}
namespace import concurrency::*
