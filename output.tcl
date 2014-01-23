package provide output 1.0
package require Tcl 8.5
package require textproc 1.0

namespace eval ::output {
  namespace export h1 h2 indent blockanchor lineanchor init_logfile print printline
  variable width 60
  variable logfile ""
  variable logfile_active 0
  variable quiet_stdout 0

  proc init_logfile {filepath} {
    ### set logfile
    set output::logfile $filepath
    set output::logfile_active 1
    log_results_clear $filepath
  }

  proc log_results_clear {target_filepath} {
    set prefix "run"
    if {[string match "*/*" $target_filepath]} {
      set filename [file tail $target_filepath]
      set path [file dirname $target_filepath]
    } else {
      set filename $target_filepath
      set path {.}
    }
    if {[file exists $target_filepath]} {
      set format_string "%G-%m%d-%H%M"
      file stat $target_filepath "time"
      set formatted_timestamp [clock format $time(ctime) -format $format_string]
      append prefix $formatted_timestamp
      set filename "${path}/${prefix}_${filename}"
      set catch_result [ catch {file rename $target_filepath $filename} ]
    }
    #create empty file
    set fname [open $target_filepath w]
    close $fname
    return $filename
  }


  proc h1 {text} {
    set this_text [format_header $text "=" 0 1]
    output::print $this_text 0
  }

  proc h2 {text} {
    set this_text [format_header $text "-" 2]
    output::print $this_text 0
  }

  proc print {text {indent_space_count 4}} {
    set this_text [indent $text $indent_space_count]
    if {$output::logfile_active} {
      set filepath $output::logfile
      set fname [open $filepath a]
      if {$text ne ""} {
        set lines [textproc::nsplit $this_text]
        foreach line $lines {
          puts $fname $line
          after 1
        }
      }
      close $fname
    }
    if {!$output::quiet_stdout} {
      foreach line [textproc::nsplit $this_text] {
        puts $line
        after 1
      }
    }
  }

  proc printline {text {indent_space_count 4}} {
    output [hr "-" $indent_space_count]
  }

  proc hr {dashmark {indent_space_count 0}} {
    set linecount [expr $output::width - $indent_space_count]
    set line [string repeat $dashmark $linecount]
    return $line
  }

  proc format_header {text dashmark {indent_space_count 0} {uppercase 0}} {
    if {$uppercase} {
      set text [string toupper $text]
    }
    set line [output::hr $dashmark $indent_space_count]
    set result_textblock {}
    foreach item [list $line $text $line] {
      append result_textblock "\n"
      append result_textblock $item
    }
    return [indent $result_textblock $indent_space_count]
  }

  proc indent {text num_spaces} {
    set newtext {}
    foreach line [textproc::nsplit $text] {
      lappend newtext "[string repeat " " $num_spaces]$line"
    }
    return [join $newtext "\n"]
  }

  proc blockanchor {text} {
    return ">>>>\n$text\n<<<<"
  }

  proc lineanchor {text} {
    set result {}
    foreach line [textproc::nsplit $text] {
      lappend result ">$line<"
    }
    return [textproc::njoin $result]
  }

}
namespace import output::*
