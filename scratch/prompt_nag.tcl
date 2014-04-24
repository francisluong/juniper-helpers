#!/usr/bin/env tclsh

package require homeless

set mytext [prompt_user "this is a prompt, type something and press ENTER:" 10]
puts "You typed: '$mytext'"

nag_user "now press ENTER or I'll keep making noise!"

