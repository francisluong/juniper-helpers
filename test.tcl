package provide test 1.0
package require Tcl 8.5
package require JuniperConnect 
package require output 
package require countdown

namespace eval ::test {
    #namespace export 
    variable lastmode {}
    variable pass 
    variable current_subcase {}
    variable analyze_buffer {}
    variable full_analyze_buffer {}
    variable subcase_list {}
    variable overall_pass {}

    proc start {testname} {
        variable pass
        variable overall_pass
        array unset pass 
        array set pass {}
        set overall_pass {}
        output::h1 "Start Test: $testname"
    }

    proc finish {} {
        variable overall_pass
        output::h2 "Test Result Summary --> $overall_pass"
        output::print [test::pass_fail_summary]
        #print closing HR
        output::print "\n[output::hr "="]" 0
        #disconnect ALL router sessions
        foreach address [array names juniperconnect::session_array] {
            disconnectssh $address
        }
        return $overall_pass
    }

    proc summary {} { return [test::pass_fail_summary] }
    proc pass_fail_summary {} {
        variable subcase_list
        variable pass
        variable overall_pass
        #print test results
        set outparts {}
        set overall_pass "PASS"
        foreach subcase $subcase_list {
            set this_pass $pass($subcase)
            set outcome "PASS"
            if {!$this_pass} {
                set outcome "FAIL"
                set overall_pass "FAIL"
            }
            lappend outparts "** $subcase --> $outcome"
        }
        lappend outparts "Summary Test Result --> $overall_pass"
        return [textproc::njoin $outparts]
    }

    proc subcase {description} {
        set subcase "Subcase: $description"
        output::h2 $subcase
        #initialize PASS for this subcase
        set test::pass($subcase) 1
        set test::current_subcase $subcase
        lappend test::subcase_list $subcase
        set test::lastmode "subcase"
    }

    proc analyze_cli {router commands_textblock {rpc 0}} {
        return [test::analyze_output $router $commands_textblock $rpc]
    }
    proc analyze_output {router commands_textblock {rpc 0}} {
        variable analyze_buffer 
        set outparts {}
        if {$test::lastmode ne "analyze"} {
            lappend outparts [output::hr "-" 4]
        }
        lappend outparts "Analyzing $router output for the following commands:"
        foreach line [textproc::nsplit $commands_textblock] {
            set line [string trim $line]
            if {$line ne ""} {
                lappend outparts "  + $line"
            }
        }
        output::print [textproc::njoin $outparts]
        if {![juniperconnect::session_exists $router]} {
            connectssh $router 
        }
        set analyze_buffer [juniperconnect::send_textblock $router $commands_textblock]
        variable full_analyze_buffer $analyze_buffer
        if {$rpc ne "0"} {
            set analyze_buffer [juniperconnect::prep_netconf_output $analyze_buffer]
        }
        set test::lastmode "analyze"
        return $analyze_buffer
    }

    proc apply_config {router commands_textblock {merge_set_override "cli"} {confirmed_simulate "0"}} {
        variable analyze_buffer
        juniperconnect::set_timeout 30
        set outparts {}
        if {$test::lastmode ne "config"} {
            print [output::hr "-" 4]
        }
        lappend outparts "Apply Configuration to $router:"
        #add commands to output
        foreach line [textproc::nsplit [string trim $commands_textblock]] {
            set line [string trim $line]
            if {$line ne ""} {
                lappend outparts "  + $line"
            }
        }
        #print output
        output::print [textproc::njoin $outparts]
        #connect if needed
        if {![juniperconnect::session_exists $router]} {
            connectssh $router
        }
        #send commands
        set analyze_buffer [juniperconnect::send_config $router $commands_textblock $merge_set_override $confirmed_simulate]
        variable full_analyze_buffer $analyze_buffer
        set test::lastmode "config"
        juniperconnect::restore_timeout
    }

    proc analyze_textblock {description textblock_contents} {
        variable analyze_buffer 
        if {$test::lastmode ne "analyze"} {
            output::print [output::hr "-" 4]
        }
        output::print "Analyzing textblock: $description"
        set analyze_buffer $textblock_contents
        set test::lastmode "analyze"
        return $analyze_buffer
    }

    proc assert {expression {assertion "present"} {value1 ""} {value2 ""}} {
        if {$test::lastmode ne "assert"} {
            output::print [output::hr "-" 4]
            output::print "> Verification of Assertions:"
        }
        switch -nocase -- $assertion {
            "present" {
                set condition "is present"
                set grep_result [textproc::grep $expression $test::analyze_buffer]
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
                set grep_result [textproc::grep $expression $test::analyze_buffer]
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
                set grep_result [textproc::grep $expression $test::analyze_buffer]
                set linecount [llength [textproc::nsplit $grep_result]]
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
            output::print "-  Confirmed: $description" 6
            #pass
        } else {
            output::print "!! ERROR: Failed to verify: $description" 4
            #fail
            set test::pass($test::current_subcase) 0
        }
        set test::lastmode "assert"
        return $this_pass
    }

    proc limit_scope {start_expression {stop_expression {^$}} {options_list ""}} {
        if {$test::lastmode ne "limit"} {
            output::print [output::hr "-" 4]
        }
        output::print "Limit Scope of output as follows:"
        output::print "* Start Expression: '$start_expression'" 6
        output::print "* Stop Expression: '$stop_expression'" 6
        if {$options_list ne ""} {
            output::print "* Options: $options_list" 6
        }
        variable analyze_buffer
        #use grep_until to match the scoped section and choose the first block
        # set the result to analyze_buffer
        set analyze_buffer [lindex [textproc::grep_until $start_expression $stop_expression $analyze_buffer $options_list] 0]
        set test::lastmode "limit"
    }

    proc xml_scope {xpath_expression {node_index "0"}} {
        if {$test::lastmode ne "limit"} {
            output::print [output::hr "-" 4]
        }
        output::print "Limit Scope of output as follows:"
        output::print "* XPATH Expression: '$xpath_expression'" 6
        variable analyze_buffer
        set domdoc [dom parse $analyze_buffer]
        set rpc_reply [$domdoc documentElement]
        set node_set [$rpc_reply selectNodes $xpath_expression]
        if {[llength $node_set] == 0} {
            #return empty document
            set analyze_buffer ""
        } else {
            #return xml document 
            set node [lindex $node_set 0]
            set analyze_buffer [$node asXML]
        }
        set test::lastmode "limit"
        return $node
    }

    proc analyze_netconf {router rpc} {
        variable analyze_buffer 
        if {$test::lastmode ne "analyze"} {
            output::print [output::hr "-" 4]
        }
        output::print "Analyzing $router output for the following rpc:"
        output::print [string trim [[dom parse $rpc] asXML]] 6
        if {![juniperconnect::session_exists "nc:$router"]} {
            connectssh $router "netconf"
        }
        set analyze_buffer [juniperconnect::send_rpc $router $rpc "ascii"]
        variable full_analyze_buffer $analyze_buffer
        set test::lastmode "analyze"
        return $analyze_buffer
    }

    proc xassert {xpath {assertion "present"}  {value1 ""} {value2 ""}} {
        variable analyze_buffer
        if {$test::lastmode ne "assert"} {
            output::print [output::hr "-" 4]
            output::print "> Verification of Assertions:"
        }
        set this_pass 1
        set domdoc [dom parse $analyze_buffer]
        set rpc_reply [$domdoc documentElement]
        set node_set [$rpc_reply selectNodes $xpath]
        set outparts [list "* xpath: $xpath"]
        if {[llength $node_set] == 0} {
            #no matching XML nodes
            set this_pass 0
            lappend outparts "* EMPTY node result set: '$node_set'"
        }
        switch -nocase -- $assertion {
            "present" {
                set description "XPATH matches one or more nodes"
                if {[llength $node_set] > 0} {
                    foreach node $node_set {
                        lappend outparts "   ([$node toXPath])"
                    }
                }
            }
            "regexp" {
                set description "XPATH text matches regexp: '$value1'"
                foreach node $node_set {
                    set this_value [$node data]
                    lappend outparts "* node data: '$this_value'"
                    set grep_result [textproc::grep $value1 $this_value]
                    if {$grep_result == ""} {
                        #no matches - fail
                        set this_pass 0
                    } else {
                        #match success
                    }
                }
            }
            "count" {
                #value1 = disposition: (<|>|==|!=|<=|>=)
                set disposition [test::sanity_boolean_disposition $assertion $value1]
                #value2 = integer: compare the line count to this value
                set compare_value $value2
                set nodecount [llength $node_set]
                set this_pass [eval "expr $nodecount $disposition $compare_value"]
                set description "# nodes matching XPATH ($nodecount) $disposition $compare_value"
            }
            "compare" {
                #value1 = disposition: (<|>|==|!=|<=|>=)
                set disposition [test::sanity_boolean_disposition $assertion $value1]
                #value2 = integer: compare the line count to this value
                set compare_value $value2
                set description "value for node matching XPATH $disposition $compare_value"
                foreach node $node_set {
                    set this_value [string trim [$node data]]
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
            output::print "-  Confirmed: $description" 6
            #pass
        } else {
            output::print "!! ERROR: Failed to verify: $description" 4
            #fail
            set test::pass($test::current_subcase) 0
        }
        output::print "[textproc::njoin $outparts]\n" 8
        set test::lastmode "assert"
        return $this_pass
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
        output::print [output::hr "-" 4]
        output::print "> Relevant CLI/RPC Output:"
        if {[catch {dom parse $analyze_buffer} doc] > 0} {
            #CLI
            switch -- [lindex [textproc::nsplit $output] end] {
                "{master}" -
                "{backup}" {
                    set output [textproc::nrange $output 0 end-2]
                }
            }
            output::print $output 6
        } else {
            #NetConf/RPC/XML
            switch -nocase -- $style {
                default {
                    output::print $output 6
                }
                "xml" -
                "rpc" {
                    set node [$doc selectNodes "//output"]
                    set rpc_reply [$doc firstChild]
                    $rpc_reply removeChild $node
                    output::print [string trim [$doc asXML]] 6
                }
                "output" -
                "ascii" {
                    output::print "(Truncating XML to ASCII output only)\n-- snip, snip --" 6
                    set node [$doc selectNodes "//output"]
                    output::print [string trim [$node asXML]] 6
                }
            }
        }
        set analyze_buffer $test::full_analyze_buffer
        set test::lastmode "end"
        return $test::pass($test::current_subcase)
    }

    proc wait {wait_seconds} {
        output::print "[output::hr "-" 4]\nWaiting for $wait_seconds seconds..."
        countdown::wait $wait_seconds
        set test::lastmode "wait"
    }

}
#namespace import test::*
