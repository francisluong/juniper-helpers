#!/usr/bin/env tclsh

package require Expect
package require mime
package require smtp
package require base64

#usage
if {$argc < 1} {
  puts "Usage: [info script] <email_address> <message>"
  exit
}

set email_address [lindex $argv 0]
if {$argc > 1} {
  set body_message [lindex $argv 1]
} else {
  set body_message "trying out tcllib mime/smtp\nline 2\rline 3"
}

set csv "name, breed, color
Scooby Doo, Great Dane, Brown
Snoopy, Beagle, White"
set message_token [mime::initialize \
  -canonical "text/plain" \
  -encoding base64 \
  -string $body_message]
set csv_token [mime::initialize \
  -canonical "text/plain; name=\"attach1.csv\"" \
  -encoding "base64" \
  -string $csv]
set a2_token [mime::initialize \
  -canonical "text/plain; name=\"attach2.txt\"" \
  -encoding "base64" \
  -string "attachment 2"]

set parts_list [list $message_token $csv_token $a2_token]

set multipart_token [mime::initialize -canonical multipart/mixed -parts $parts_list]

set smtp_result [smtp::sendmessage $multipart_token \
  -header [list From "Nobody <nobody@juniper.net>"] \
  -header [list To $email_address] \
  -header [list Subject "tcllib mime/smtp test -- [clock format [clock seconds]]"]]

puts "To $email_address"
puts "Subject tcllib mime/smtp test -- [clock format [clock seconds]]"
puts "Body $body_message"
puts "smtp_result: '$smtp_result'"

mime::finalize $multipart_token -subordinates all
