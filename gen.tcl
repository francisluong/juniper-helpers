package provide gen 1.1
package require Tcl 8.5
package require ip
package require yaml
package require homeless

namespace eval ::gen {
    #generators of lists
    #namespace export XXX

    proc range {start stop {incrementBy 1}} {
        set resultList {}
        for {set i $start} {$i < $stop} {incr i $incrementBy} {
            lappend resultList $i
        }
        return $resultList
    }

    proc ipv4 {start_address count {increment "0.0.0.1"}} {
        set result_list {}
        set addr_hex [ip::toHex $start_address]
        set incr_hex [ip::toHex $increment]
        for {set i 0} {$i < $count} {incr i} {
            set ipv4_addr_slash [ip::nativeToPrefix $addr_hex]
            lassign [split $ipv4_addr_slash "/"] addr mask
            lappend result_list $addr
            set addr_hex [expr $addr_hex + $incr_hex]
        }
        return $result_list
    }

    proc config_from_yaml {yaml_filepath} {
        #generate a router config from yaml
        set yaml_full [yaml::yaml2dict [read_file $yaml_filepath]]
        #one top level key for each section of config - repeat for each section
        foreach key [dict keys $yaml_full] {
            set dict_yaml_section [dict get $yaml_full $key]
            puts "#$key"
            set config_section [gen::_process_yaml_config_section $dict_yaml_section]
            puts $config_section
        }
        return $config_section
    }

    proc _process_yaml_config_section {dict_yaml_section} {
        set keys [dict keys $dict_yaml_section]
        #process simple substitutions
        if {[dict exists $dict_yaml_section simple_substitutions]} {
            foreach {varname value} [dict get $dict_yaml_section simple_substitutions] {
                set $varname $value
            }
        }
        #process generators
        array unset gen_values 
        array set gen_values [list "count" 1]
        if {[lsearch -exact $keys "generators"] != -1} {
            set dict_generators [dict get $dict_yaml_section generators]
            array set gen_values [::gen:_process_yaml_generators $dict_generators]
        }
        #perform substitutions into config section
        set config [dict get $dict_yaml_section config]
        set result_config {}
        #...repeat config for each gen_values(count)
        for {set x 0} {$x < $gen_values(count)} {incr x} {
            foreach this_key [array names gen_values] {
                set $this_key [lindex $gen_values($this_key) $x]
            }
            append result_config [subst $config]
        }
        return $result_config
    }

    proc _process_yaml_generators {dict_generators} {
        #process all generators and return a list for each generator
        # result_dict is a key-value list
        # also return a value of "count" of the shortest list(s)
        set result_dict {}
        set shortest_list_length 1
        foreach key [dict keys $dict_generators] {
            #make a call to iteration 
            set this_dict [gen::_iteration_yaml_generator $key [dict get $dict_generators $key]]
            #... then add the results to the kvlist
            set result_dict [dict merge $result_dict $this_dict]
        }
        #array set this_gen $kv_range_params
        #calculate and append count to key-value list
        dict set result_dict "count" [::gen:_shortest_list_in_dict $result_dict]
        return $result_dict
    }

    proc _shortest_list_in_dict {dictionary_values} {
        set shortest_list_length {}
        dict for {key value} $dictionary_values {
            set this_length [llength $value]
            if {$shortest_list_length eq ""} {
                #just accept the first value
                set shortest_list_length $this_length
            } else {
                if {$shortest_list_length != $this_length} {
                    # "mismatched list sizes... taking the lesser"
                    if {$this_length < $shortest_list_length} {
                        set shortest_list_length $this_length
                    }
                } 
            }
        }
        return $shortest_list_length
    }

    proc _iteration_yaml_generator {keyname dict_generator} {
        #recursable local name space for yaml generation
        dict with dict_generator {
            set repeat_times 1
            if {[info exists "then"]} {
                #then clause exists... recurse 
                set result_dict {}
                foreach key [dict keys $then] {
                    #merge each result_dict into main result_dict
                    set this_result_dict [::gen:_iteration_yaml_generator $key [dict get $then $key]]
                    set result_dict [dict merge $result_dict $this_result_dict]
                    #update repeat_times based on shortest list length
                    set repeat_times [::gen:_shortest_list_in_dict $result_dict]
                }
            } else {
                set result_dict {}
            }
            #perform generation for this level
            if {![info exists type]} {
                set type "range"
            }
            switch -nocase -- $type {
                "ipv4" {
                    if {![info exists increment]} {
                        set increment "0.0.0.1"
                    }
                    set genresult [gen::ipv4 $start $count $increment]
                }
                default {
                    #generate a number list
                    if {![info exists increment]} {
                        set increment 1
                    }
                    set genresult [gen::range $start $stop $increment]
                }
            }
            #perform repeats if needed
            if {$repeat_times != 1} {
                #preserve and init genresult
                set oldresult $genresult
                set genresult {}
                #init array for each key in result_dict (inner level)
                dict for {key value} $result_dict {
                    set inner($key) {}
                }
                foreach value $oldresult {
                    #for top level, we repeat each value for the count of shortest list
                    for {set x 0} {$x < $repeat_times} {incr x} {
                        lappend genresult $value
                    }
                    #for each inner level list we repeat the whole sequence 
                    #...for each top level value
                    dict for {key value} $result_dict {
                        set inner($key) [concat $inner($key) $value]
                    }
                }
                #write back new inner values
                foreach name [array names inner]  {
                    dict set result_dict $name $inner($name)
                }
            }
            #add new genresult to result_dict
            dict set result_dict $keyname $genresult
        }
        #would like to add a proc that strips the lists down to common shortest
        return $result_dict
    }

}
namespace import gen::*
