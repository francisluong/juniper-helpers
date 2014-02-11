package provide test 1.0
package require Tcl 8.5
package require JuniperConnect 1.0
package require output 1.0

namespace eval ::test {
  #namespace export 
  variable lastmode {}
  variable pass 
  variable current_subcase {}
  variable analyze_buffer {}

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
    set outparts {}
    set overall_pass "PASS"
    foreach subcase [array names test::pass] {
      set this_pass $test::pass($subcase)
      set outcome "PASS"
      if {!$this_pass} {
        set outcome "FAIL"
        set overall_pass "FAIL"
      }
      lappend outparts "** $subcase --> $outcome"
    }
    #lappend outparts "--" "Test Result: $overall_pass"
    h2 "Test Result Summary --> $overall_pass"
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

  proc analyze_cli {router commands_textblock} {
    return [analyze_output $router $commands_textblock]
  }
  proc analyze_output {router commands_textblock} {
    variable analyze_buffer 
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
    set analyze_buffer [send_textblock $router $commands_textblock]
    set test::lastmode "analyze"
  }

  proc analyze_textblock {description textblock_contents} {
    variable analyze_buffer 
    print "Analyzing textblock: $description"
    set analyze_buffer $textblock_contents
  }

  proc assert {expression {assertion "present"} {value1 ""} {value2 ""}} {
    if {$test::lastmode ne "assert"} {
      print [output::hr "-" 4]
      print "> Verification of Assertions:"
    }
    switch -nocase -- $assertion {
      "present" {
        set condition "is present"
        set grep_result [grep $expression $test::analyze_buffer]
        if {$grep_result ne ""} {
          set this_pass 1
        } else {
          set this_pass 0
        }
        set description "'$expression' $condition"
      }
      "notpresent" -
      "not present" {
        set condition "is NOT present"
        set grep_result [grep $expression $test::analyze_buffer]
        if {$grep_result eq ""} {
          set this_pass 1
        } else {
          set this_pass 0
        }
        set description "'$expression' $condition"
      }
      "count" -
      "match and count" {
        #value1 = disposition: (<|>|==|!=|<=|>=)
        set disposition $value1
        #value2 = integer: compare the line count to this value
        set compare_value $value2
        #sanity check disposition
        set exp {(<|>|==|!=|<=|>=)}
        if {![regexp -- $exp $disposition]} {
          return -code error "[info proc] $assertion: unexpected value1 '$value1' -- (should match $exp)"
        }
        set grep_result [grep $expression $test::analyze_buffer]
        set linecount [llength [nsplit $grep_result]]
        set condition "# lines matching '$expression' ($linecount) $disposition $compare_value"
        set this_pass [eval "expr $linecount $disposition $compare_value"]
        set description $condition
      }
      "other" {
        #grab a value and compare it
        return -code error "need to implement this"
      }
      default {
        return -code error "juniperconnect::assert - unexpected assertion type: '$assertion'"
      }
    }
    if {$this_pass} {
      print "-  Confirmed: $description" 6
      #pass
    } else {
      print "!! ERROR: Failed to verify: $description" 4
      #fail
      set test::pass($test::current_subcase) 0
    }
    set test::lastmode "assert"
  }

  proc end_analyze {} {
    variable analyze_buffer
    print [output::hr "-" 4]
    print "> Relevant CLI Output:"
    set output $analyze_buffer
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
