package provide countdown 1.0

namespace eval ::countdown {

  proc run_eval {count {unit "seconds"} eval} {
   ###########################################
   # abstract: sleeps for a total of $count milliseconds providing CLI feedback every $increment milliseconds
   #    further, runs [$eval] every $increment
   #
   # inputs: 
   #    - count - total sleep duration in milliseconds
   #    - increment - interval in milliseconds that countdown remain will be provided to CLI
   #    - eval - tcl eval string - may need to escape some characters to get this to work
   # returns: 
   #    - nothing
   ###########################################
     switch -nocase -- $unit {
       "ms" -
       "msec" -
       "milliseconds" {
        set divisor 1
        set increment 1000
       }
       default -
       "sec" -
       "seconds" {
        #even though we default to seconds, the calculations are all done in ms
        set divisor 1000
        set count [expr $count * $divisor]
        set increment [expr 10 * $divisor]
       }
     }
     set buffering [fconfigure stdout -buffering]
     fconfigure stdout -buffering none
     set current_display_value [expr $count/$divisor]
     set display_increment [expr $increment/$divisor]
     puts -nonewline "sleeping for $current_display_value $unit..."
     set timer_start_ms [clock clicks -milliseconds]
     set current_click_offset 0
     while {$current_click_offset<$count} {
       puts -nonewline $current_display_value
       set index [expr $count-$current_click_offset]
       if {$index<$increment} {
         dotdotdot $index 
       } else {
         dotdotdot $increment
       }
       eval $eval
       set current_display_value [expr $current_display_value-$display_increment]
       set current_clicks [clock clicks -milliseconds]
       set current_click_offset [expr $current_clicks - $timer_start_ms]
     }
     puts "0"
     fconfigure stdout -buffering $buffering
  }  

  proc wait {count {unit "seconds"} {eval ""}} {
   ###########################################
   # abstract: sleeps for a total of $count seconds providing CLI feedback every {$increment 10} milliseconds
   #    further, runs [$eval] every $increment
   #
   # inputs: 
   #    - count - total sleep duration in milliseconds
   #    - increment - interval in milliseconds that countdown remain will be provided to CLI
   #    - eval - tcl eval string - may need to escape some characters to get this to work
   # returns: 
   #    - nothing
   ###########################################
    run_eval $count $unit $eval
  }

  proc dotdotdot {count} {
   ###########################################
   # abstract: sleeps for $count milliseconds providing one dot for each $count/3 milliseconds
   #
   # inputs: 
   #    - count - sleep duration in milliseconds
   # returns: 
   #    - nothing
   ###########################################

    set increment [expr $count/3]
    for {set index 0} {$index<3} {set index [expr $index+1]} {
      after $increment
      puts -nonewline {.}
    }

  }
}
