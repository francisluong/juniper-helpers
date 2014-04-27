#!/usr/bin/env tclsh

package require countdown

proc ps {{pid_check ""}} {
    set result [exec /usr/bin/env ps]
    if {$pid_check eq ""} {
        return $result
    } else {
        return [regexp -line -nocase -- "^$pid_check .*" $result]
    }
}

#pid
set pingpid [exec ping -c 5 127.0.0.1 > /dev/null &]
puts "Ping PID: $pingpid"
puts "PS: [ps]"
countdown::run_eval "puts \"PS Ping: \[ps $pingpid\]\"" 20 seconds
