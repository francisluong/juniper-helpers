package provide textproc 1.0
package require textutil::split
package require Tcl     8.5
package require tdom

namespace eval ::textproc {
    namespace export grep grep_until nsplit njoin nrange column split_on_empty_line

    proc nsplit {textblock} {
        #take a textblock and return a list consisting of lines
        set lines_list [split $textblock "\n"]
        return $lines_list
    }

    proc njoin {lines_list} {
        # take a list and join with "\n"
        set result_textblock [join $lines_list "\n"]
        return $result_textblock
    }

    proc nrange {textblock rangestart {rangestop ""}} {
        if {$rangestop eq ""} {
            set rangestop $rangestart
        }
        #line lrange but for "\n" delimited textblocks
        set lines_list [[namespace current]::nsplit $textblock]
        set after_lines_list [lrange $lines_list $rangestart $rangestop]
        set result [[namespace current]::njoin $after_lines_list]
    }

    proc split_on_empty_line {textblock} {
        #split a textblock on fully empty lines: \n\n
        set result [textutil::split::splitx $textblock "\n\n"]
        if {[llength $result] == 1} {
            set result [lindex $result 0]
        }
        return $result
    }

    proc column {column_number_list textblock {field_separator ""} {format "list"}} {
        #awk-like column grab
        #return a lindex-split for all lines in textblock
        #column numbers start with 1, not 0
        set result_list {}
        foreach line [[namespace current]::nsplit $textblock] {
            set new_line_parts_list {}
            if {$field_separator eq ""} {
                set splitline $line
            } else {
                set splitline [split $line $field_separator]
            }
            foreach index $column_number_list {
                incr index "-1"
                lappend new_line_parts_list [lindex $splitline $index]
            }
            lappend result_list [join $new_line_parts_list " "]
        }
        switch -- $format {
            "list" {
                return $result_list
            }
            "textblock" {
                set result [[namespace current]::njoin $result_list]
                return $result
            }
            default {
                return -code error "extract_column_to_list: unexpected value for format: '$format'"
            }
        }
    }

    proc linematch {expression textblock} {
        return [grep $expression $textblock]
    }

    proc linematch_nocase {expression textblock} {
        return [grep $expression $textblock "nocase"]
    }

    proc linematch_inverse {expression textblock} {
        return [grep $expression $textblock "inverse"]
    }
    
    proc grep {expression textblock {options_list ""}} {
        set inverse 0
        set ignore_case 0
        foreach option $options_list {
            switch -nocase -- $option {
                "invert"  -
                "inverse"  {set inverse 1}
                "nocase" -
                "ignore_case" {set ignore_case 1}
            }
        }
        if {[string index $expression 0] ne "^"} {
            set expression "^.*$expression"
        }
        if {[string index $expression end] ne {$}} {
            set expression "$expression.*\$"
        }
        #inverse matching requires line-by-line
        set result {}
        foreach line [[namespace current]::nsplit $textblock] {
            if {$ignore_case} {
                set regexp_true [regexp -line -nocase -- $expression $line]
            } else {
                set regexp_true [regexp -line -- $expression $line]
            }
            if {$inverse} {
                set print_this_line [expr !$regexp_true]
            } else {
                set print_this_line $regexp_true
            }
            if {$print_this_line} {
                lappend result $line
            }
        }
        return [[namespace current]::njoin $result]
    }

    proc grep_until {start_expression stop_expression textblock {options_list ""} } {
        set stop_inverse 0
        set start_inverse 0
        set stop_ignore_case 0
        set start_ignore_case 0
        set once 0
        foreach option $options_list {
            switch -- $option {
                "once" {
                    set once 1
                }
                "inverse"  {
                    set start_inverse 1
                    set stop_inverse 1
                }
                "start_inverse"  {
                    set start_inverse 1
                }
                "stop_inverse"  {
                    set stop_inverse 1
                }
                "nocase" -
                "ignore_case" {
                    set start_ignore_case 1
                    set stop_ignore_case 1
                }
                "start_nocase" -
                "start_ignore_case" {
                    set start_ignore_case 1
                }
                "stop_nocase" -
                "stop_ignore_case" {
                    set stop_ignore_case 1
                }
            }
        }
        set result {}
        set state "init"
        set this_block {}
        foreach line [[namespace current]::nsplit $textblock] {
            string trim $line
            switch -- $state {
                "init" { 
                    set expression $start_expression
                    set ignore_case $start_ignore_case
                    set inverse $start_inverse
                }
                "printuntilstop" { 
                    set expression $stop_expression
                    set ignore_case $stop_ignore_case
                    set inverse $stop_inverse
                }
            }
            set match 0
            if {$ignore_case} {
                set regexp_true [regexp -nocase -- $expression $line]
            } else {
                set regexp_true [regexp -- $expression $line]
            }
            if {$regexp_true} {
                if {!$inverse} { 
                    set match 1
                }
            } else {
                if {$inverse} { 
                    set match 1
                }
            }
            switch -- $state {
                "init" { 
                    if {$match} {
                        lappend this_block $line 
                        set state "printuntilstop"
                    }
                }
                "printuntilstop" { 
                    lappend this_block $line 
                    if {$match} {
                        lappend result [[namespace current]::njoin $this_block]
                        if {$once} {break}
                        set state "init"
                        set this_block {}
                    }
                }
            }
        }
        return $result
    }

    proc get_xml_text {xmltext xpath_statement {strim "strim"}} {
        if {![string match "*/text()" $xpath_statement]} {
            set xpath_statement "[string trimright $xpath_statement "/"]/text()"
        }
        set domdoc [dom parse $xmltext]
        set docroot [$domdoc documentElement]
        set node_set [$docroot selectNodes $xpath_statement]
        set result_list {}
        if {[llength $node_set] == 1} {
            set node [lindex $node_set 0]
            if {$strim eq "strim"} {
                set result [string trim [$node data]]
            } else {
                set result [$node data]
            }
            return $result
        } else {
            foreach node $node_set {
                if {$strim eq "strim"} {
                    set result [string trim [$node data]]
                } else {
                    set result [$node data]
                }
                lappend result_list $result
            }
            return $result_list
        }
    }

}

namespace import textproc::*

