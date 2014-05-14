#!/usr/bin/env tclsh

package require JuniperConnect
package require gen
package require output
package require test
package require concurrency
package require yaml
package require delim

#set concurrency::debug 1

#usage
set usagestring "Usage: $argv0 <userpass_file> <path_to_delim_config_file> <delimiter> \[<router_column=0> <config_column=1>\] \[test\]"
if {$argc < 3} {
    puts stderr $usagestring
    exit
} 


#child thread iteration proc
proc child_thread_iteration {router} {
    #child needs to call iter_thread_start as first action
    iter_thread_start
    set options [yaml::yaml2dict [iter_get_stdin]]
    set test [dict get $options test]
    if {$test} {
        set confirmed_simulate "simulate"
    } else {
        set confirmed_simulate "confirmed"
    }
    #read in userpass data
    import_userpass [dict get $options "userpass_file"]
    # do stuff
    set commands_textblock [dict get $options commands_textblock]
    test::subcase "Configure $router"
    test::apply_config $router $commands_textblock "set" $confirmed_simulate
    test::assert "configuration check succeeds"
    if {!$test} {
        test::assert "commit complete"
    }
    set pass [test::end_analyze]
    if {$pass} {
        set returncode 0
    } else {
        set returncode 1
    }
    #child thread proc needs to call iter_thread_finish as final action with return code as only arg
    iter_thread_finish $returncode
}


#optional stdin generator proc... this is suppled to concurrency::process_queue 
proc stdin_gen {router} {
    global argv router_commands_dict test
    #pass path to userpass file to child as "userpass_file"
    dict set options "userpass_file" [lindex $argv 0]
    #pass commands_textblock
    global commands_textblock
    dict set options "commands_textblock" [njoin [dict get $router_commands_dict $router]]
    dict set options "router" $router
    dict set options "test" $test
    return [yaml::dict2yaml $options]
}

concurrency::init "child_thread_iteration"
set concurrency::max_threads 20

#read in userpass data
import_userpass [lindex $argv 0]

#if last argv item is "test" then set test to 1 else 0
if {[string match -nocase "test" [lindex $argv end]]} {
    set test 1
    set realargs [expr $argc - 1]
} else {
    set test 0
    set realargs $argc
}

#if indexes 3 and 4 are present
set column(router) 0
set column(config) 1
if {$realargs > 3} {
    if {$realargs == 4} {
    #error if only 4 real args... if we are specifying router column, must also specify config column
        puts stderr $usagestring
        exit
    } elseif {$realargs == 5} {
        set column(router) [lindex $argv 3]
        set column(config) [lindex $argv 4]
    }
} 


#import delim filename... delim file should be formatted as <router,command>
set filepath [lindex $argv 1]
set split_char [lindex $argv 2]
#start a log file based on delim filename(.results.txt)
init_logfile "$filepath.results.txt"

set delim_content [string trim [read_file $filepath]]
#perform sanity check
set sanity_firstline [lindex [split $delim_content "\n"] 0]
set sanity_router [lindex [split $sanity_firstline $split_char] $column(router)]
set sanity_config [lindex [split $sanity_firstline $split_char] $column(config)]
set sanity_pass 1
if {![regexp "^(set|delete|deactivate|activate|annotate|replace) .*" $sanity_config]} {
    set sanity_pass 0
}
if {!$sanity_pass} {
    puts stderr "\n"
    puts stderr $usagestring
    puts stderr "\nERROR!! Sanity Check Failed: router $sanity_router, config: $sanity_config"
    puts stderr "\nPlease check your router and config columns selections and try again\n"
    exit
}

set delim_dict [delim::import $delim_content $split_char]
set router_commands_dict [delim::group_by_column $delim_dict $column(router) $column(config)]


h1 "Routers"
set candidate_routers_list [dict keys $router_commands_dict]
h2 "-- FINAL ROUTER LIST ------------------"

foreach router $candidate_routers_list {
    print " - $router"
}
set routers_list $candidate_routers_list


#validate config with user and wait for confirmation
if {$test} {
    output::h1 "Config (Test Run -- COMMIT CHECK ONLY)"
} else {
    output::h1 "Config"
}
#read and generate configuration
set router [lindex $routers_list 0]
set grep_output [textproc::grep $router $delim_content]
set commands_textblock [njoin [dict get $router_commands_dict [lindex $routers_list 0]]]
print "[string trim $grep_output]\n---\n[string trim $commands_textblock]"
set csv_linecount [llength [nsplit $delim_content]]
set dict_valuecount 0
dict for {router commands_list} $router_commands_dict {
    incr dict_valuecount [llength $commands_list]
}
print "---\nCSV Linecount: $csv_linecount vs. Commands count: $dict_valuecount"
if {$csv_linecount eq $dict_valuecount} {
    print " ==> COUNTS ARE EQUAL"
} else { 
    print " ==> COUNTS ARE NOT EQUAL"
}
nag_user "--\nReview Configuration...\n Press ENTER to Continue -- or -- Press CTRL-C to Cancel."

#execute commands on routers
test::start "Apply Configs to Routers"
#process queue concurrently, sending the return value of [stdin_gen $queue_item] to each thread instance
concurrency::process_queue $routers_list "stdin_gen"

h1 "Report Results"
concurrency::report_detail
concurrency::report_pass_fail
