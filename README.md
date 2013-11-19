Intro
-----
So I started writing the code in this repo before I gave a lot of thought to what it would be and now that I've been writing for a bit I think I am ready.

I intend for this to be a library of TCL/Expect for interaction with Juniper devices.  Here are some of the types of interaction I will account for:
  - login
  - configure or send commands
  - get output
  - do stuff with it

I will include sufficient text processing helpers to make it really easy to extract information.  Where possible, I will attempt to use native TCL to maximize platform independence.
  - given a text block, return lines matching regular expression (ala crude grep)
  - given a text block, return a list of textblocks starting with one expression and ending with another
  - given a text block, return a list of strings derived from each line corresponding to a column number given a field separator (ala crude awk)
  - given a textblock, if the textblock matches a regular expression, return 1 - else return 0

Prerequisites
-------------
 - TCL 8.5
 - tcllib
 - Expect 5.45
 - OpenSSH

This repo is actively being developed.  Consider it informal for now.

Sub-Folders
-----------
I will keep non-TCL library items in the following subfolders:
 - slax: op/event/commit scripts
 - python: experimental python for router interaction

-Franco
