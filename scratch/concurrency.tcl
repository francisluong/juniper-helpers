
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
#

package provide concurrency 1.0
package require base32
package require output

namespace eval concurrency {

  variable max_threads 5
  variable wait_seconds 10
  variable input_queue {}
  variable active_queue {}
  variable finished_queue {}
  variable thread_iteration_procname {}
  variable iteration_match_text "RUN_THREAD_ITERATION"
  variable iteration_argv_index 0

  #these are used if it is a thread_iteration
  variable tmp_folder "/var/tmp"
  variable is_thread_iteration 0
  variable queue_item {}
  variable ofilename {}

  proc init {thread_iteration_procname} {
    # call this early in your application... 
    # it will kick off thread_iteration proc if applicable
    # otherwise we assume it's the main queue handler
    global argc argv   
    variable iteration_match_text
    variable iteration_argv_index
    #if this is an iteration, run it and exit
    if {[lindex $argv $iteration_argv_index] eq $iteration_match_text} {
      #setup some variables
      variable is_thread_iteration 1
      variable ofilename [base32::encode $queue_item]
      variable queue_item [lindex $argv 1]
      #call thread_iteration and exit 
      exit [$thread_iteration_procname $queue_item]
    }
    #initialize things
    set concurrency::input_queue {}
    set concurrency::current_queue {}
    set concurrency::finished_queue {}
    #probably won't need this
    set concurrency::thread_iteration_procname $thread_iteration_procname
  }

  proc process_queue {input_queue} {
    # call this when we are all setup and we want to start the run
    #initialize
    set concurrency::input_queue $input_queue
    set queue_empty 0
    set queue_item 0
    #loop until we are done with the queue
    while {!$queue_empty} {
      #start a new thread if we can, if not... returns -1
      while {$queue_item != -1} {
        #started a new thread... try to start more until we get a return of -1
        set queue_item [_next_item]
        _main_thread_start $queue_item
      }
      #perform wait unless complete
      if {!$complete} {
        after [expr $concurrency::wait_seconds * 1000]
      }
      #finish each item that is ready
      foreach queue_item $concurrency::current_queue {
        _main_thread_finish ${queue_item}
      }
      #check to see if we are done with the queue
      set queue_empty [_queue_is_empty]
    }
  }

  proc iter_thread_start {} {
    variable queue_item
    set outfile [_output_filepath $queue_item]
    #
  }

  proc iter_thread_finish {} {
    variable queue_item
    set ofilename [base32::encode $queue_item]
    #is a thread_iteration
    #output flag to indicate thread_iteration is complete
    print "\n$ofilename"
    return
  }

  #======================
  # INTERNAL PROCS
  #======================

  proc _next_item {} {
    #get next item or return -1
    #return -1 if no sessions are available
    set this_item "-1"
    set current_sessions [llength concurrency::current_queue]
    if {[llength $concurrency::input_queue] != 0 && ($current_sessions < $concurrency::max_threads)} {
      #dequeue
      set this_item [lindex $concurrency::input_queue 0]
      set concurrency::input_queue [lrange $concurrency::input_queue 1 end]
      #add to current_list
      lappend concurrency::current_queue $this_item
    }
    return $this_item
  }

  proc _main_thread_start {queue_item} {
    #runfile - path to thread script
    #queue_item - the text of the concurrency queue item
    set path [generate_results_path $routername]
    puts "Start: $routername - $path"
    variable iteration_match_text
    set outfile [output_filepath $queue_item]
    exec [info script] $iteration_match_text $queue_item $outfile >& /dev/null &
  }

  proc _main_thread_finish {queue_item} {
    set finished 0
    set outfile [output_filepath $queue_item]
    set ofilename [base32::encode $queue_item]
    variable is_thread_iteration 
    #read file

    #get last line

    #if last line == $ofilename, thread_iteration is complete
    if { $last_line eq $ofilename } {
      set finished 1
      set index [lsearch -exact $concurrency::current_queue $this_item]
      if {$index != -1} {
        #match found
        #delete this_item from current_list
        set concurrency::current_queue [lreplace $concurrency::current_queue $index $index]
        #add this_item to finished_list
        set concurrency::finished_queue $this_item
      } else {
        #match not found
        return -code error "concurrency::thread_finish: dequeuing problem: $queue_item not found"
      }
    } else {
      #not finished
    }
    return $finished
  }

  proc _queue_is_empty {} {
    set input_empty 0
    set current_empty 0
    if {[llength $concurrency::input_queue] == 0} {
      set input_empty 1
    }
    if {[llength $concurrency::current_queue] == 0} {
      set current_empty 1
    }
    if {$input_empty && $current_empty} {
      return 1
    } else {
      return 0
    }
  }

  proc _output_filepath {queue_item} {
    set format_string "%G-%m%d"
    set today [clock format [clock seconds] -format $format_string]
    set ofilename [base32::encode $queue_item]
    return "$concurrency::tmp_folder/$today.$ofilename.txt"
  }

}
