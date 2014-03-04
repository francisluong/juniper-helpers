package provide test 1.0
package require Tcl 8.5
package require JuniperConnect 1.0
package require output 1.0
package require countdown

namespace eval ::test {
  #namespace export 
  variable lastmode {}
  variable pass 
  variable current_subcase {}
  variable analyze_buffer {}
  variable full_analyze_buffer {}
  variable subcase_list {}

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
    foreach subcase $test::subcase_list {
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
    lappend test::subcase_list $subcase
    set test::lastmode "subcase"
  }

  proc analyze_cli {router commands_textblock} {
    return [analyze_output $router $commands_textblock]
  }
  proc analyze_output {router commands_textblock} {
    variable analyze_buffer 
    set outparts {}
    if {$test::lastmode ne "subcase"} {
      lappend outparts [output::hr "-" 4]
    }
    lappend outparts "Analyzing $router output for the following commands:"
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
    variable full_analyze_buffer $analyze_buffer
    set test::lastmode "analyze"
  }

  proc apply_config {router commands_textblock} {
    variable analyze_buffer
    juniperconnect::set_timeout 30
    set outparts {}
    if {$test::lastmode ne "subcase"} {
      lappend outparts [output::hr "-" 4]
    }
    lappend outparts "Apply Configuration to $router:"
    #sanitize config - add configure private and/or commit and-quit if needed
    set commands_list [nsplit [string trim $commands_textblock]]
    set first [lindex $commands_list 0]
    set changed 0
    if {![string match "*config*" $first]} {
      set commands_list [linsert $commands_list 0 "configure private"]
      set changed 1
    }
    set last [lindex $commands_list end]
    if {![string match "*commit*" $last]} {
      set commands_list [linsert $commands_list end "commit and-quit"]
      set changed 1
    }
    if {$changed} {
      set commands_textblock [njoin $commands_list]
    }
    #add commands to output
    foreach line [nsplit $commands_textblock] {
      set line [string trim $line]
      if {$line ne ""} {
        lappend outparts "  + $line"
      }
    }
    #print output
    print [njoin $outparts]
    #connect if needed
    if {![juniperconnect::session_exists $router]} {
      connectssh $router
    }
    #send commands
    set analyze_buffer [send_textblock $router $commands_textblock]
    variable full_analyze_buffer $analyze_buffer
    set test::lastmode "analyze"
    juniperconnect::restore_timeout
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

  proc limit_scope {start_expression {stop_expression {^$}} {options_list ""}} {
    if {$test::lastmode ne "subcase"} {
      print [output::hr "-" 4]
    }
    print "Limit Scope of output as follows:"
    print "* Start Expression: '$start_expression'" 6
    print "* Stop Expression: '$stop_expression'" 6
    if {$options_list ne ""} {
      print "* Options: $options_list" 6
    }
    variable analyze_buffer
    #use grep_until to match the scoped section and choose the first block
    # set the result to analyze_buffer
    set analyze_buffer [lindex [grep_until $start_expression $stop_expression $analyze_buffer $options_list] 0]
  }

  proc analyze_netconf {router rpc} {
    variable analyze_buffer 
    if {$test::lastmode ne "subcase"} {
      print [output::hr "-" 4]
    }
    print "Analyzing $router output for the following rpc:"
    print [string trim [[dom parse $rpc] asXML]] 6
    if {![juniperconnect::session_exists "nc:$router"]} {
      connectssh $router "netconf"
    }
    set analyze_buffer [send_rpc $router $rpc "ascii"]
    variable full_analyze_buffer $analyze_buffer
    set test::lastmode "analyze"
  }

  proc xassert {xpath {assertion "present"}  {value1 ""} {value2 ""}} {
    if {$test::lastmode ne "assert"} {
      print [output::hr "-" 4]
      print "> Verification of Assertions:"
    }
    set domdoc [dom parse $test::analyze_buffer]
    set rpc_reply [$domdoc documentElement]
    set node_set [$rpc_reply selectNodes $xpath]
    set outparts [list "* xpath: $xpath"]
    switch -nocase -- $assertion {
      "present" {
        set description "XPATH matches one or more nodes"
        if {[llength $node_set] > 0} {
          set this_pass 1
          foreach node $node_set {
            lappend outparts "   ([$node toXPath])"
          }
        } else {
          set this_pass 0
        }
      }
      "regexp" {
        set description "XPATH text matches regexp: '$value1'"
        set this_pass 1
        foreach node $node_set {
          set this_value [$node data]
          set grep_result [grep $value1 $this_value]
          if {$grep_result == ""} {
            set this_pass 0
          } else {
            lappend outparts "   ($this_value)"
          }
        }
      }
      "count" {
        #value1 = disposition: (<|>|==|!=|<=|>=)
        set disposition [sanity_boolean_disposition $assertion $value1]
        #value2 = integer: compare the line count to this value
        set compare_value $value2
        set nodecount [llength $node_set]
        set this_pass [eval "expr $nodecount $disposition $compare_value"]
        set description "# nodes matching XPATH ($nodecount) $disposition $compare_value"
      }
      "compare" {
        #value1 = disposition: (<|>|==|!=|<=|>=)
        set disposition [sanity_boolean_disposition $assertion $value1]
        #value2 = integer: compare the line count to this value
        set compare_value $value2
        set description "value for node matching XPATH $disposition $compare_value"
        set this_pass 1
        foreach node $node_set {
          set this_value [$node data]
          set this_node_pass [eval "expr $this_value $disposition $compare_value"]
          if {!$this_node_pass} {
            set this_pass 0
          } else {
            lappend outparts "   ($this_value)"
          }
        }
      }
      default {
        return -code error "juniperconnect::nc_assert - unexpected assertion type: '$assertion'"
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
    print "[njoin $outparts]\n" 8
    set test::lastmode "assert"
  }

  proc sanity_boolean_disposition {assertion disposition} {
    set exp {(<|>|==|!=|<=|>=)}
    if {![regexp -- $exp $disposition]} {
      return -code error "[info proc] $assertion: unexpected disposition '$disposition' -- (should match $exp)"
    } else {
      return $disposition
    }
  }

  proc end_analyze {{style "default"}} {
    variable analyze_buffer
    set output $analyze_buffer
    print [output::hr "-" 4]
    print "> Relevant CLI/RPC Output:"
    if {[catch {dom parse $analyze_buffer} doc] > 0} {
      #CLI
      switch -- [lindex [nsplit $output] end] {
        "{master}" -
        "{backup}" {
          set output [nrange $output 0 end-2]
        }
      }
      print $output 6
    } else {
      #NetConf/RPC/XML
      switch -nocase -- $style {
        default {
          print $output 6
        }
        "xml" -
        "rpc" {
          set node [$doc selectNodes "//output"]
          set rpc_reply [$doc firstChild]
          $rpc_reply removeChild $node
          print [string trim [$doc asXML]] 6
        }
        "output" -
        "ascii" {
          print "(Truncating XML to ASCII output only)\n-- snip, snip --" 6
          set node [$doc selectNodes "//output"]
          print [string trim [$node asXML]] 6
        }
      }
    }
    set analyze_buffer $test::full_analyze_buffer
  }

  proc wait {wait_seconds} {
    print "[output::hr "-" 4]\nWaiting for $wait_seconds seconds..."
    countdown::wait $wait_seconds
    set test::lastmode "wait"
  }

}
#namespace import test::*
