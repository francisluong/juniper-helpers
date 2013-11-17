package provide textproc 1.0
package require textutil::split
package require Tcl     8.5

namespace eval ::textproc {
  #namespace export grep

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

  proc nrange {textblock rangestart rangestop} {
    #line lrange but for "\n" delimited textblocks
    set lines_list [nsplit $textblock]
    set after_lines_list [lrange $lines_list $rangestart $rangestop]
    set result [njoin $after_lines_list]
  }

  proc split_on_empty_line {textblock} {
    #split a textblock on fully empty lines: \n\n
    set result [textutil::split::splitx $textblock "\n\n"]
    return $result
  }

  proc extract_column {field_separator column_number_list textblock} {
    #similar to awk
    #column numbers start with 1, not 0
    set result_list [extract_column_to_list $field_separator $column_number_list $textblock]
    set result [njoin $result_list]
    return $result
  }

  proc extract_column_to_list {field_separator column_number_list textblock} {
    #similar to awk
    #column numbers start with 1, not 0
    set result_list {}
    foreach line [nsplit $textblock] {
      set new_line_parts_list {}
      set splitline [split $line $field_separator]
      foreach index $column_number_list {
        incr index "-1"
        lappend new_line_parts_list [lindex $splitline $index]
      }
      lappend result_list [join $new_line_parts_list]
    }
    return $result_list
  }


  proc linematch {expression textblock} {
    if {[string index $expression 0] ne "^"} {
      set expression "^.*$expression"
    }
    if {[string index $expression end] ne {$}} {
      set expression "$expression.*\$"
    }
    return [njoin [regexp -all -inline -line -- \
      $expression $textblock]]
  }

  proc linematch_nocase {expression textblock} {
    #ignore case
    if {[string index $expression 0] ne "^"} {
      set expression "^.*$expression"
    }
    if {[string index $expression end] ne {$}} {
      set expression "$expression.*\$"
    }
    return [njoin [regexp -all -inline -line -nocase -- \
      $expression $textblock]]
  }

  proc linematch_inverse {expression textblock} {
    return [tcl_grep_uber $expression "inverse" $textblock]
  }
  
  proc tcl_grep_uber {expression options_list textblock} {
    set inverse 0
    set ignore_case 0
    foreach option $options_list {
      switch -- $option {
        "inverse"  {set inverse 1}
        "nocase" -
        "ignore_case" {set ignore_case 1}
      }
    }
    set result {}
    foreach line [nsplit $textblock] {
      if {$ignore_case} {
        set regexp_true [regexp -nocase -- $expression $line]
      } else {
        set regexp_true [regexp -- $expression $line]
      }
      if {$regexp_true} {
        if {!$inverse} { lappend result $line }
      } else {
        if {$inverse} { lappend result $line }
      }
    }
    return [njoin $result]
  }

  proc grep_until {start_expression stop_expression textblock} {
    return [grep_until_option $start_expression $stop_expression "" $textblock]
  }

  proc grep_until_option {start_expression stop_expression options_list textblock} {
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
    foreach line [nsplit $textblock] {
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
            lappend result [njoin $this_block]
            if {$once} {break}
            set state "init"
            set this_block {}
          }
        }
      }
    }
    return $result
  }


}

#namespace import 

