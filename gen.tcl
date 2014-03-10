package provide gen 1.0
package require Tcl 8.5
package require ip

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

  proc ipv4 {start_address count {increment 0.0.0.1}} {
    set result_list {}
    set addr_hex [ip::toHex $start_address]
    set incr_hex [ip::toHex $increment]
    for {set i 0} {$i < $count} {incr i} {
      set ipv4_addr_slash [ip::nativeToPrefix $addr_hex]
      lassign [split $ipv4_addr_slash "/"] addr mask
      lappend result_list $addr
      set addr_hex [expr $addr_hex + $incr_hex]
    }
    return $result_list
  }

}
namespace import gen::*
