package provide output 1.0
package require Tcl 8.5
package require textproc 1.0

namespace eval ::output {
  namespace export h1 h2 indent blockanchor lineanchor

  proc h1 {text} {
    puts "\n\n[string toupper $text]"
    set line [string repeat = 60]
    puts $line
  }

  proc h2 {text} {
    puts "\n\n[string toupper $text]"
    set line [string repeat - 50]
    puts $line
  }

  proc indent {text num_spaces} {
    set newtext {}
    foreach line [split $text "\n"] {
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
