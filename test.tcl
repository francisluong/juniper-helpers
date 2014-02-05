package provide test 1.0
package require Tcl 8.5
package require JuniperConnect 1.0
package require output 1.0

namespace eval ::test {
  #namespace export 
  variable lastmode {}
  variable pass 
  variable current_subcase {}

  proc start {testname} {
    variable pass
    array unset pass 
    array set pass {}
    h1 "Start Test: $testname"
  }

  proc finish {} {
    #disconnect ALL router sessions
    foreach address [array names juniperconnect::session_array] {
      disconnectssh $address
    }
    #print test results
    h2 "Test Results Summary"
    set outparts {}
    set overall_pass "PASS"
    foreach subcase [array names test::pass] {
      set this_pass $test::pass($subcase)
      set outcome "PASS"
      if {!$this_pass} {
        set outcome "FAIL"
        set overall_pass "FAIL"
      }
      lappend outparts "$subcase --> $outcome"
    }
    lappend outparts "--" "Test Result: $overall_pass"
    print [njoin $outparts]
    #print closing HR
    print "\n[output::hr "="]" 0
  }

  proc subcase {description} {
    set subcase "Subcase: $description"
    h2 $subcase
    #initialize PASS for this subcase
    set test::pass($subcase) 1
    set test::current_subcase $subcase
  }

  proc analyze_output {router commands_textblock} {
    set outparts [list "Analyzing $router output for the following commands:"]
    foreach line [nsplit $commands_textblock] {
      set line [string trim $line]
      if {$line ne ""} {
        lappend outparts "  + $line"
      }
    }
    print [njoin $outparts]
    if {![juniperconnect::session_exists $router]} {
      connectssh $router 
    }
    send_textblock $router $commands_textblock
    set test::lastmode "analyze"
  }

  proc assert {expression {assertion "present"}} {
    if {$test::lastmode ne "assert"} {
      print [output::hr "-" 4]
      print "> Verification of Assertions:"
    }
    switch -nocase -- $assertion {
      "present" {
        set condition "is present"
        set grep_result [grep_output $expression]
        if {$grep_result ne ""} {
          print "-  Confirmed: '$expression' $condition" 6
          #pass
        } else {
          print "!! ERROR: Failed to verify: '$expression' $condition" 4
          #fail
          set test::pass($test::current_subcase) 0
        }
      }
      default {
        return -code error "juniperconnect::assert - unexpected assertion type: '$assertion'"
      }
    }
    set test::lastmode "assert"
  }

  proc end_analyze {} {
    print [output::hr "-" 4]
    print "> Relevant CLI Output:"
    set output $juniperconnect::output
    switch -- [lindex [nsplit $output] end] {
      "{master}" -
      "{backup}" {
        set output [nrange $output 0 end-2]
      }
    }
    print $output 6
  }

  proc within {} {
  }

  proc config {} {
  }

}
#namespace import test::*
