
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
# Master Script
# ================
#
# the master script will work through a list of items, called "input_queue"
# this will be the only input into the thread_iteration script
#
# when starting a thread_iteration, it will spawn process as background process
# until there are a number running equal to "max_threads"
#
# 
#
#Procs that need to be supplied - application specific
#=======================================================
# - proc thread_start - a proc that starts the thread
#     * needs to generate a an output filename and store it in an array 
#     * needs to call the thread script and redirect output to /dev/null 
#     * e.g. exec $runfile $routername $path >& /dev/null &
# - proc thread_finish - a proc that determines whether a thread is finished
#     * needs to know what file to check
#     * needs to know what to match to determine whether a script is finished
# - proc usage - check argv to see if it is a thread iteration or the main
#
#[ ]how do I provide it with inputs?
#[ ]
#
#Other notes
#===============
# - application script will have the main and the thread iteration and will call itself for iteration
# - 
#

namespace eval concurrency {

  variable max_threads 5
  variable wait_seconds 10
  variable input_queue {}
  variable active_queue {}
  variable finished_queue {}
  variable thread_iteration_procname {}
  variable iteration_match_text "RUN_THREAD_ITERATION"
  variable iteration_argv_index 0

  proc init {input_queue thread_iteration_procname} {
    global argc argv   
    variable iteration_match_text
    variable iteration_argv_index
    #if this is an iteration, run it and exit
    if {[lindex $argv $iteration_argv_index] eq $iteration_match_text} {
      #call thread_iteration and exit 
      exit [$thread_iteration_procname [lindex $argv 1]]
    }
    set concurrency::input_queue $input_queue
    set concurrency::current_queue {}
    set concurrency::finished_queue {}
    #probably won't need this
    set concurrency::thread_iteration_procname $thread_iteration_procname
  }

  proc main_concurrent {input_queue} {
    variable max_threads
    variable wait_seconds

    set complete 0
    #loop until we are done with the queue
    while {!$complete} {

      #start a new thread if we can, if not... returns -1
      set queue_item [next_item]
      while {$queue_item != -1} {

        #started a new thread... try to start more until we get a return of -1
        thread_start $queue_item
        set queue_item [next_item]
      }
      
      #perform wait unless complete
      if {!$complete} {countdown_sec $wait_seconds 1}

      #finish each item that is ready
      foreach queue_item $concurrency::current_queue {
        thread_finish ${queue_item}
      }
      set complete [concurrency_complete]
    }
  }

  proc next_item {} {
    #get next item or return -1
    #return -1 if no sessions are available
    set this_item "-1"
    set current_sessions [llength concurrency::current_queue
    if {[llength $concurrency::input_queue] != 0 && $current_sessions < $concurrency::max_threads} {
      #dequeue
      set this_item [lindex $concurrency::input_queue 0]
      set concurrency::input_queue [lrange $concurrency(input_list) 1 end]
      #add to current_list
      lappend concurrency::current_queue $this_item
      #bump current_sessions counter
      incr concurrency(current_sessions)
    }
    return $this_item
  }

  proc concurrency_finish {this_item} {
    set index [lsearch -exact $concurrency::current_queue $this_item]
    if {$index != -1} {
      #match found
      #delete this_item from current_list
      set concurrency::current_queue [lreplace $concurrency(current_list) $index $index]
      #add this_item to finished_list
      set concurrency::finished_queue $this_item
      #decrement concurrency(current_sessions)
      incr concurrency(current_sessions) -1
      return 1
    } else {
      return 0
    }
  }

  proc concurrency_complete {} {
    set input_empty 0
    set current_empty 0
    if {[llength [concurrency_input_list]] == 0} {
      set input_empty 1
    }
    if {[llength [concurrency_current_list]] == 0} {
      set current_empty 1
    }
    if {$input_empty && $current_empty} {
      return 1
    } else {
      return 0
    }
  }

  proc concurrency_input_list {} {
    return $concurrency::input_queue
  }

  proc concurrency_current_list {} {
    return $concurrency::current_queue
  }

  proc concurrency_finished_list {} {
    return $concurrency::finished_queue
  }

  proc generate_results_path {routername} {
    return "/var/tmp/concurrency.tcl.${routername}.txt"
  }

  proc thread_start {runfile queue_item} {
    #runfile - path to thread script
    #queue_item - the text of the concurrency queue item
    set path [generate_results_path $routername]
    puts "Start: $routername - $path"
    exec $runfile $routername $path >& /dev/null &
  }

  proc finish_collection {routername} {
    global results
    set path [generate_results_path $routername]
    set grepExpression "LAT FINISH"
    if { [catch {exec egrep $grepExpression $path}]>0 } {
      set finished 0
    } else {
      set finished 1
    }
    if {$finished} {
      concurrency_finish $routername
      puts "--"
      puts "Finish: $routername - Current: [concurrency_current_list]"
      #log result
      set file_contents [read_file $path]
      set file_contents [join [lrange [split $file_contents "\n"] 0 end-2] "\n"]
      global cfm_sanity
      set cfm_sanity($routername) $file_contents
      log_to_file $results [string trim $file_contents]
      #delete file
      file delete -force $path
      puts "--"
    } else {
      puts "Incomplete: $routername - Current: [concurrency_current_list]"
    }
  }

}
