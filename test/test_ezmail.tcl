#!/usr/bin/env tclsh

package require ezmail

if {$argc < 1} {
    puts "Usage: [info script] <from_email_address> <target_email_address>..."
    exit
} 
set from_address [lindex $argv 0]
ezmail::init $from_address
ezmail::start_message "ezmail.[clock seconds]" "Subject Text"
ezmail::add_body "this is the body of the email\nline 2"
ezmail::add_attachment "0,1,2,3" test.csv
ezmail::send [lrange $argv 1 end]
