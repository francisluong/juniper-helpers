#!/usr/bin/env tclsh

package require JuniperConnect
package require yaml
package require output

package provide oc 1.0

namespace eval ::oc {

  variable options_dict {}

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
    set valid [verify_template $filepath $template_dict]
    if {$valid} {
      output::pdict template_dict
      dict with template_dict {
        #add $output_folder to $folder
        set folder "[dict get $options_dict "output_folder"]/$folder"
        #create folder if it doesn't exist
        file mkdir $folder
        #if folder is writable we can continue
        if {[file writable $folder]} {
          puts " >> Processing Template: $filepath"
          set routers_list [dict get $options_dict $router_list_name]
          foreach router $routers_list {
            #connect and get output
            if {[info exists "netconf"]} {
              connectssh $router netconf
              set output_text [send_rpc $router $netconf]
              disconnectssh $router netconf
            } else {
              connectssh $router
              set output_text [send_textblock $router $commands]
              disconnectssh $router
            }
            #write output to file
            set fl [open "$folder/$router" w]
            puts $fl [string trim $output_text]
            close $fl
          }
        }  else {
          print " !! Templated Failed: Folder not writable: $folder - template $filepath"
        }
      }
    }
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

}

