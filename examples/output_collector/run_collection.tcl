#!/usr/bin/env tclsh

package require JuniperConnect
package require yaml
package require output


proc verify_options {options_dict} {
  set pass 1
  foreach key [list "path_main" "path_templates" "output_folder"] {
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
  foreach key [list "folder" "router_list_name" "commands"] {
    if {[lsearch -exact $keys_list $key] == -1} {
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
          connectssh $router
          set output_text [send_textblock $router $commands]
          #write output to file
          set fl [open "$folder/$router" w]
          puts $fl [string trim $output_text]
          close $fl
          #disconnect session
          disconnectssh $router
        }
      }  else {
        print " !! Templated Failed: Folder not writable: $folder - template $filepath"
      }
    }
  }
}

proc run_collection {options_dict} {
  #now process files in path_templates
  dict with options_dict {
    foreach infile [glob $path_templates/*] {
      set file_contents [read_file $infile]
      #only process non-empty files
      if {$file_contents ne ""} {
        set template_dict [yaml::yaml2dict $file_contents]
        process_template $infile $template_dict $options_dict
      }
    }
  }
}

#usage
if {$argc < 1} {
  puts "Usage: [info script] <path_to_userpass_file>"
  exit
} 
#read in userpass file
import_userpass [lindex $argv 0]
#read in etc/config.yml
set collector_dir [file dir $argv0]
set options_dict [yaml::yaml2dict [read_file "${collector_dir}/etc/config.yml"]]
output::pdict options_dict
#verify it
verify_options $options_dict
#you can also 'dict set options_dict' to add router lists
#dict set options_dict router_list_3 $xyz

#now we run collection
run_collection $options_dict
