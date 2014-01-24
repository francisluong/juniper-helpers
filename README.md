TCL Library
===========

Intro
-----
WARNING: This repo is actively being developed.  Consider it informal for now.

I intend for this to be a library of TCL/Expect for interaction with Juniper devices.  Here are some of the types of interaction I will account for:
  - login
  - configure or send commands
  - get output
  - do stuff with it

Prerequisites
-------------
 - TCL 8.5
 - tcllib
 - Expect 5.45
 - OpenSSH

Installing these packages
 * Ubuntu Install: _sudo apt-get install -y tcl8.5 expect tcllib openssh_
 * Fedora/Redhat/Centos Install: _sudo yum install -y tcl expect tcllib openssh_

Getting Started
---------------

The library is written in TCL so you just have to clone the repo and add it to your TCLLIBPATH.

Steps for BASH:
 - Clone the repository
 - Add the path of this git repo to TCLLIBPATH in your ~/.bashrc
   * _export TCLLIBPATH=$TCLLIBPATH:/home/fluong/juniper-helpers_
 - create a userpass file
   * first line should be username
   * second line should have the password
   * e.g. _examples/userpass_
 - Try to run examples/001\_basic.tcl  
   * _examples/001\_basic.tcl <router_address> <path_to_userpass_file>_
   * you will need a Juniper router you have access to in order to execute this script

Library Files
-------------
 - test.tcl - high-level Juniper router test interface
 - juniper_connect.tcl - expect/ssh handlers
 - textproc.tcl - text processing
 - output.tcl - output, and logging

Test Support - test.tcl
-----------------------
This is a high-level testing framework for connecting with routers, performing actions, getting outputs, and verifying them.  See examples/001_basic.tcl for a brief example.

Text Processing - textproc.tcl
------------------------------
I will include sufficient text processing helpers to make it really easy to extract information.  Where possible, I will attempt to use native TCL to maximize platform independence.
  - given a text block, return lines matching regular expression (ala crude grep)
  - given a text block, return a list of textblocks starting with one expression and ending with another
  - given a text block, return a list of strings derived from each line corresponding to a column number given a field separator (ala crude awk)
  - given a textblock, if the textblock matches a regular expression, return 1 - else return 0


Other Content
=============

Sub-Folders
-----------
I will keep non-TCL library items in the following subfolders:
 - slax: op/event/commit scripts
 - python: experimental python for router interaction

-Franco
