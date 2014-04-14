    package require countdown 

    puts [clock format [clock seconds]]
    countdown::wait 30 seconds
    puts [clock format [clock seconds]]
    countdown::wait 1000 ms
    puts [clock format [clock seconds]]
    exit

