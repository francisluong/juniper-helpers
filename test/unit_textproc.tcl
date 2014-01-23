#!/usr/bin/env tclsh
set auto_path [linsert $auto_path 0 "/home/fluong/code/juniper-helpers"]
package require output
package require textproc

h1 "Nsplit and NJoin"
set textindent "x
y
z"
h2 "original text"
print $textindent
h2 "nsplit"
set textnsplit [nsplit $textindent]
print $textnsplit
h2 "njoin"
set textnjoin [njoin $textnsplit]
print $textnjoin
h2 "indent"
print [indent $textindent 2]

h1 "Attempt to return a list based on \\n\\n split"
set text1 "block1
block1

block2
block2"
set block1 [split_on_empty_line $text1]
print $block1

h1 "attempt case sensitive match"
set expression "BLOCK1"
h2 "expression: $expression"
print [indent [blockanchor [grep $expression $text1]] 2]

h1 "attempt case insensitive match"
h2 "expression: $expression"
print [indent [blockanchor [grep $expression $text1 "nocase"]] 2]

h1 "inverse match"
set expression "block1"
h2 "expression: $expression"
print [indent [blockanchor [grep $expression $text1 "nocase"]] 2]

h1 "extract_column 2"
set text2 "1 2 3
a b c
bob"
print [indent [blockanchor [column 2 $text2 " "]] 2]


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
print [indent [blockanchor $text3] 2]
h2 "after grep_until"
print [indent [blockanchor [grep_until $start $stop $text3]] 2]
