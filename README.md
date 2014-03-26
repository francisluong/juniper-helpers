TCL Library
===========

Intro
-----
_WARNING: This repo is actively being developed.  Consider it informal for now._

I intend for this to be a library of TCL/Expect for interaction with Juniper devices.  Here are some of the types of interaction I will account for:
  - login via cli or NetConf
  - perform configuration or send commands for output
  - process output 
  - generate configurations
  - write tests to validate outputs

Prerequisites
-------------
 - TCL 8.5, and these libraries:
   * tcllib
   * tdom
   * expect 
 - OpenSSH

*Installing these packages*

Ubuntu Install: 

```
sudo apt-get install -y tcl8.5 expect tcllib tdom openssh
```
 
Fedora/Redhat/Centos Install: 

```
sudo yum install -y tcl expect tcllib tdom openssh
```

Getting Started
---------------

The library is written in TCL so you just have to clone the repo and add it to your TCLLIBPATH.

Steps for BASH:
 - Clone the repository
 - Either... Add the path of this git repo to TCLLIBPATH in your ~/.bashrc
   * _export TCLLIBPATH=/home/fluong/juniper-helpers_
 - ...or you can symlink the folder from a place listed in $tcl_pkgPath
   * e.g. 'sudo ln -s /home/fluong/juniper-helpers /usr/lib/juniper-helpers'
 - create a [userpass](https://github.com/francisluong/juniper-helpers/blob/master/examples/userpass) file
   * first line should be username
   * second line should have the password
   * e.g. _examples/userpass_
 - Try to run examples/001_basic.tcl  
   * Usage: *examples/001\_basic.tcl (router_address) (path_to_userpass_file)*
   * you will need a Juniper router you have access to in order to execute this script

```
export TCLLIBPATH=/home/fluong/juniper-helpers
sudo ln -s /home/fluong/juniper-helpers /usr/lib/juniper-helpers
```

Library Packages
-----------------
 - JuniperConnect - Expect-based SSH/Netconf handlers
 - test - perform testcases to validate output against Juniper router test interface
 - gen - create lists and generate configuration from YAML files
 - textproc - text handling helpers
 - output - output formatting and logging

Basic SSH and NetConf - package require JuniperConnect
--------------------------------------------------------
This uses Expect and a call to OpenSSH to connect to a router using either CLI or NetConf.  Send commands, get output.  See examples/001\* 002\* 003\*

Test Cases - package require test
--------------------------------------
This is a high-level testing framework for connecting with routers, performing actions, getting outputs, and verifying them.  See examples/001_basic.tcl for a brief example.

Text Processing - package require textproc
--------------------------------------------
I will include sufficient text processing helpers to make it really easy to extract information.  Where possible, I will attempt to use native TCL to maximize platform independence.
  - given a text block, return lines matching regular expression (ala crude grep)
  - given a text block, return a list of textblocks starting with one expression and ending with another
  - given a text block, return a list of strings derived from each line corresponding to a column number given a field separator (ala crude awk)
  - given a textblock, if the textblock matches a regular expression, return 1 - else return 0

Generate Config - package require gen
----------------------------------------
Generate router configs.  Particularly, large ones with repeating sections.  See examples/100*

Output - package require output
---------------------------------
Create log files, output to log and screen.  Make stuff look pretty and presentable.


Other Content
=============

Sub-Folders
-----------
I will keep non-TCL library items in the following subfolders:
 - slax: op/event/commit scripts
 - python: experimental python for router interaction

-Franco
