#!/usr/bin/env tclsh

package require JuniperConnect
package require yaml
package require concurrency
package require output

package provide oc 1.0

namespace eval ::oc {

    variable options_dict {}
    variable to_stdin_dict {}
    variable path_to_userpass_file {}

    proc load_config {filepath_config_yml} {
        variable options_dict
        set yaml_in [read_file $filepath_config_yml]
        set options_dict [yaml::yaml2dict $yaml_in]
        output::pdict options_dict
        #verify it
        oc::verify_options
    }

    proc verify_options {} {
        variable options_dict
        set pass 1
        foreach key [list "path_templates" "output_folder"] {
            set filepath [file normalize [dict get $options_dict $key]]
            if {([file isdirectory $filepath] && [file writable $filepath])} {
                #good
            } else {
                puts stderr "Filepath $filepath doesn't exist or not writable"
            }
        }
        if {!$pass} {
            exit
        }
    }

    proc verify_template {filepath template_dict} {
        set valid 1
        set keys_list [dict keys $template_dict]
        foreach key [list "folder" "router_list_name" "(commands|netconf)"] {
            if {[lsearch -regexp $keys_list $key] == -1} {
                set valid 0
            }
        }
        if {$valid} {
        } else {
            puts " !! Template Failed Verify: $filepath"
        }
        return $valid
    }

    proc process_template {filepath template_dict options_dict} {
        variable to_stdin_dict
        set to_stdin_dict {}
        set valid [verify_template $filepath $template_dict]
        if {$valid} {
            output::pdict template_dict
            #pack commands/netconf into to_stdin_dict
            foreach key [list "commands" "netconf"] {
                if {[dict exists $template_dict $key]} {
                    dict set to_stdin_dict $key [dict get $template_dict $key]
                }
            }
            #add $output_folder to $folder
            set folder [string trim [dict get $template_dict "folder"]]
            set output_folder [string trim [dict get $options_dict "output_folder"]]
            set folder "$output_folder/$folder"
            dict set to_stdin_dict "folder" $folder
            #create folder if it doesn't exist
            file mkdir $folder
            #if folder is writable we can continue
            if {[file writable $folder]} {
                puts " >> Processing Template: $filepath"
                set router_list_name [dict get $template_dict "router_list_name"]
                set routers_list [dict get $options_dict $router_list_name]
                #process queue concurrently
                concurrency::process_queue $routers_list "oc::stdin_gen"
            }  else {
                print " !! Templated Failed: Folder not writable: $folder - template $filepath"
            }
        }
    }

    proc init {in_path_to_userpass_file} {
        concurrency::init "oc::child_thread_iteration"
        variable path_to_userpass_file 
        set path_to_userpass_file $in_path_to_userpass_file
    }

    proc run_collection {} {
        variable options_dict
        #now process files in path_templates
        dict with options_dict {
            foreach infile [lsort [glob $path_templates/*]] {
                set file_contents [read_file $infile]
                #only process non-empty files
                if {$file_contents ne ""} {
                    set template_dict [yaml::yaml2dict $file_contents]
                    process_template $infile $template_dict $options_dict
                }
            }
        }
    }

    #optional stdin generator proc... this is suppled to concurrency::process_queue 
    proc stdin_gen {router} {
        variable path_to_userpass_file
        variable to_stdin_dict
        #pass path to userpass file to child as "userpass_file"
        dict set to_stdin_dict "userpass_file" $path_to_userpass_file
        return [yaml::dict2yaml $to_stdin_dict]
    }

    proc child_thread_iteration {router} {
        #child needs to call iter_thread_start as first action
        iter_thread_start
        set options [yaml::yaml2dict [iter_get_stdin]]
        dict with options {
            #read in userpass data
            import_userpass [dict get $options "userpass_file"]
            #connect and get output
            if {[info exists "netconf"]} {
                connectssh $router netconf
                set returncode [catch {send_rpc $router $netconf} output_text]
                disconnectssh $router netconf
            } else {
                connectssh $router
                set returncode [catch {send_textblock $router $commands} output_text]
                disconnectssh $router
            }
            #write output to file
            set folder [string trim $folder]
            set router [string trim $router]
            set fl [open "$folder/$router" w]
            puts $fl [string trim $output_text]
            close $fl
        }
        output::print $output_text
        #child thread proc needs to call iter_thread_finish as final action with return code as only arg
        iter_thread_finish $returncode
    }
}



