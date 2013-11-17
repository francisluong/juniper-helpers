#!/usr/bin/env tclsh
set auto_path [linsert $auto_path 0 "/home/fluong/code/juniper-helpers"]
package require output
package require textproc

h1 "Nsplit and NJoin"
set textindent "x
y
z"
h2 "original text"
puts $textindent
h2 "nsplit"
set textnsplit [textproc::nsplit $textindent]
puts $textnsplit
h2 "njoin"
set textnjoin [textproc::njoin $textnsplit]
puts $textnjoin
h2 "indent"
puts [indent $textindent 2]

h1 "Attempt to return a list based on \\n\\n split"
set text1 "block1
block1

block2
block2"
set block1 [textproc::split_on_empty_line $text1]
puts $block1

h1 "attempt case sensitive match"
set expression "BLOCK1"
h2 "expression: $expression"
puts [indent [blockanchor [textproc::linematch $expression $text1]] 2]

h1 "attempt case insensitive match"
h2 "expression: $expression"
puts [indent [blockanchor [textproc::linematch_nocase $expression $text1]] 2]

h1 "inverse match"
set expression "block1"
h2 "expression: $expression"
puts [indent [blockanchor [textproc::linematch_inverse $expression $text1]] 2]

h1 "extract_column 2"
set text2 "1 2 3
a b c
bob"
puts [indent [blockanchor [textproc::extract_column " " 2 $text2]] 2]


h1 "grep_until 1 a"
set text3 "1 2 3
a b c
x y z
1 3 5
a c e
j k l"
set start "1"
set stop "a"
h2 "original text"
puts [indent [blockanchor $text3] 2]
h2 "after grep_until"
puts [indent [blockanchor [textproc::grep_until $start $stop $text3]] 2]
