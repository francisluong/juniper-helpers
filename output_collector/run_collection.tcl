#!/usr/bin/env tclsh

package require oc

#set concurrency::debug 1
set concurrency::max_threads 20

#usage
if {$argc < 2} {
    puts "Usage: [info script] <path_to_userpass_file> <path_to_config.yml>"
    exit
} 
#read in userpass file
oc::init 
import_userpass [lindex $argv 0]

#read in config.yml
set filepath_config_yml [lindex $argv 1]
oc::load_config $filepath_config_yml

#you can also 'dict set options_dict' to add router lists
    #dict set oc::options_dict router_list_3 $xyz

#now we run collection
oc::run_collection 
