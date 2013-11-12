#!/usr/bin/tclsh

package require JuniperConnect
juniperconnect::connectssh 192.168.1.31 lab lab123
juniperconnect::disconnect 192.168.1.31
puts end
