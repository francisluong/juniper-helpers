#!/usr/bin/env tclsh

#time limited execution
set slave [interp create]
interp limit $slave time -seconds [clock add [clock seconds] 5 seconds]
interp eval $slave {
    set x 0
    while {1} {
        puts "$x"
        after 1000
        incr x
    }
}
