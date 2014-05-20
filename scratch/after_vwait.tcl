#!/usr/bin/env tclsh

package require output
output::init_logfile "/var/tmp/results"

proc count {seconds} {
    global forever
    for {set x 0} {$x < $seconds} {incr x} {
        output::print "$x"
        after 1000
    }
    output::print "PASS"
    set forever 1
}

after 8000 exit
count 10
vwait forever
exit



#time limited execution should pass
set value "GLOBAL VALUE"
set slave1 [interp create]
puts "slave1: $slave1"
puts "aliases: [interp aliases]"
interp limit $slave1 time -seconds [clock add [clock seconds] 5 seconds]
interp eval $slave1 {
    package require output
    #puts $value
    for {set x 0} {$x < 4} {incr x} {
        output::print "$x"
        after 1000
    }
    output::print "PASS"
    #exit
}

#time limited execution should fail
set slave2 [interp create]
puts "slave2: $slave2"
interp limit $slave2 time -seconds [clock add [clock seconds] 5 seconds]
interp eval $slave2 {
    package require output
    set x 0
    while {1} {
        output::print "$x"
        after 1000
        incr x
    }
    output::print "FAIL"
}
