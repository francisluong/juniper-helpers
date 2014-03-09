package provide gen 1.0
package require Tcl 8.5

namespace eval ::gen {
  #generators of lists
  #namespace export h1 h2 indent blockanchor lineanchor init_logfile print printline

  proc range {start stop {incrementBy 1}} {
    set resultList {}
    for {set i $start} {$i < $stop} {incr i $incrementBy} {
      lappend resultList $i
    }
    return $resultList
  }


}
namespace import gen::*
