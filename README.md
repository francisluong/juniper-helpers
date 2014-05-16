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
sudo apt-get install -y tcl8.5 expect tcllib tdom openssh-client
```
 
Fedora/Redhat/Centos Install: 

```
sudo yum install -y tcl expect tcllib tdom openssh
```

Getting Started
---------------

Here are simple steps for BASH on Ubuntu (other linux variants may require minor changes):

Step 1. 
If you have root/sudo - Clone the repository into /usr/lib (or any path listed in $tcl_pkgPath)

```
cd /usr/lib
sudo git clone https://github.com/francisluong/juniper-helpers.git
```

Step 1. (Alternate) 
Or... If you DON'T have root/sudo - clone to a user folder and add the path of this git repo to TCLLIBPATH (perhaps in your ~/.bashrc)

```
mkdir ~/lib
cd ~/lib
git clone https://github.com/francisluong/juniper-helpers.git
export TCLLIBPATH=~/lib
```
Step 2. 
Create a [userpass](https://github.com/francisluong/juniper-helpers/blob/master/examples/userpass) file
   * first line should be username
   * second line should have the password

```
username
password
```

Step 3. 
Try to run examples/000_test_install.tcl. Output of examples/000_test_install.tcl should look something like this:

```
Tcl Version: 8.6
Tcl Package Path on your computer:
 - /usr/local/lib/tcltk
 - /usr/local/share/tcltk
 - /usr/lib/tcltk/x86_64-linux-gnu
 - /usr/lib/tcltk
 - /usr/share/tcltk
 - /usr/lib/tcltk/tcl8.6
 - /usr/lib

Attempting to access package JuniperConnect
 - SUCCESS!


============================================================
LIBRARY PATH: /HOME/FLUONG/JUNIPER-HELPERS
============================================================
    Tcl Version: 8.6

  ----------------------------------------------------------
  Expect
  ----------------------------------------------------------
    Confirmed installation of Expect: 5.45
    /usr/lib

  ----------------------------------------------------------
  tcllib
  ----------------------------------------------------------
    Confirmed installation of TCL Standard Library: tcllib//YAML: 0.3.6

  ----------------------------------------------------------
  tdom
  ----------------------------------------------------------
    Confirmed installation of TCL Document Object Model: tdom 0.8.3

  ----------------------------------------------------------
  ssh
  ----------------------------------------------------------
    Confirmed OpenSSH: OpenSSH_6.6p1 Ubuntu-2ubuntu1, OpenSSL 1.0.1f 6 Jan 2014

  ----------------------------------------------------------
  Juniper-Helpers Library installation
  ----------------------------------------------------------
    Confirmed Juniper-Helpers Library installation
    ---
    JuniperConnect 1.0  ==> found at /home/fluong/juniper-helpers/juniper_connect.tcl
    concurrency 1.0     ==> found at /home/fluong/juniper-helpers/concurrency.tcl
    countdown 1.0       ==> found at /home/fluong/juniper-helpers/countdown.tcl
    delim 1.0   ==> found at /home/fluong/juniper-helpers/delim.tcl
    ezhtml 1.0  ==> found at /home/fluong/juniper-helpers/ezhtml.tcl
    ezmail 1.0  ==> found at /home/fluong/juniper-helpers/ezmail.tcl
    gen 1.1     ==> found at /home/fluong/juniper-helpers/gen.tcl
    homeless 1.0        ==> found at /home/fluong/juniper-helpers/homeless.tcl
    output 1.1  ==> found at /home/fluong/juniper-helpers/output.tcl
    test 1.0    ==> found at /home/fluong/juniper-helpers/test.tcl
    textproc 1.0        ==> found at /home/fluong/juniper-helpers/textproc.tcl
```

Library Packages
-----------------
 - JuniperConnect - Expect-based SSH/Netconf handlers
 - test - perform testcases to validate output against Juniper router test interface
 - gen - create lists and generate configuration from YAML files
 - textproc - text handling helpers
 - output - output formatting and logging
 - concurrency - harness for launching parallel scripts and working through a queue of them
 - ezhtml - provides a simplified interface into tdom to generate html, useful for e-mail generation
 - ezmail - provides a simplified interface for smtp and mime to generate e-mails and attachments

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

ConfigGen - package require gen
----------------------------------------
Generate router configs.  Particularly, large ones with repeating sections.  See [examples/100_yaml_config_template.tcl](https://github.com/francisluong/juniper-helpers/blob/master/examples/100_yaml_config_template.tcl)

File and Screen Output - package require output
-------------------------------------------------
Create log files, output to log and screen.  Make stuff look pretty and presentable.

Easy HTML - package require ezhtml
-------------------------------------
Incrementally build an HTML document.  Useful for generating a formatted body of an e-mail or a web page.

Easy Mail - package require ezmail
-------------------------------------
Incrementally build an e-mail and send it, with attachments!!!.  Useful for sending off the results of your script.

Concurrency - package require concurrency
------------------------------------------
Provides a framework for writing scripts that work through a list of routers and send commands to each... except it's more general than that.  The queue can be a list of anything.  You can pass a dict to each child script, and even generate different values for each child.  The master script handles spawning up to some maximum number of concurrent scripts and working through the queue until it is empty.  Results are picked up by the master script for easy reporting.  
Also, this script avoids the need for having the child script in a separate file by having concurrency::init intelligently branch if it is the master thread or a child.

See examples/2xx\*.


Other Content
=============

Sub-Folders
-----------
I will keep non-TCL library items in the following subfolders:
 - slax: op/event/commit scripts
 - python: experimental python for router interaction

-Franco
