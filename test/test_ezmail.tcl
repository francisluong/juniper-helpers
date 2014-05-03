#!/usr/bin/env tclsh

package require ezmail

if {$argc < 1} {
    puts "Usage: [info script] <target_email_address>..."
    exit
} 
ezmail::start_message "ezmail.[clock seconds]" "Subject Text"
ezmail::add_body "this is the body of the email\nline 2"
ezmail::add_attachment "0,1,2,3" test.csv
ezmail::send $argv
