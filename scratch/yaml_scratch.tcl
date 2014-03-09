#!/usr/bin/env tclsh8.5

package require output
package require gen
package require homeless


proc yaml_generate {kv_range_params} {
  puts $kv_range_params
  # return same key and generated list as value
  if {[dict exists $kv_range_params "increment"]} {
    set increment [dict get $kv_range_params increment]
  } else {
    set increment 1
  }
  array set this_gen $kv_range_params
  set genresult [gen::range $this_gen(start) $this_gen(stop) $increment]
  return $genresult
}


puts [subst "YAML!!"]
puts [package require yaml]
set filepath "/home/fluong/juniper-helpers/scratch/test.yml"
set yaml_full [yaml::yaml2dict [read_file $filepath]]
puts $yaml_full
puts "keys: [dict keys $yaml_full]"
foreach key [dict keys $yaml_full] {
  puts "\n\n === $key ===\n"
  set yaml_in [dict get $yaml_full $key]
  puts $yaml_in
  output::pdict yaml_in
  set keys [dict keys $yaml_in]
  puts "keys: $keys"
  #add simple subs to variable space
  foreach {varname value} [dict get $yaml_in simple_substitutions] {
    set $varname $value
  }
  #process generators
  array unset gen_values 
  array set gen_values {}
  set count {}
  if {[lsearch -exact $keys "generators"] != -1} {
    foreach this_key [dict keys [dict get $yaml_in "generators"]] {
      array unset this_gen
      set kv_range_params [dict get $yaml_in generators $this_key]
      set gen_values($this_key) [yaml_generate $kv_range_params]
      #get the length of the list and either set or compare with count... must be same
      set this_count [llength $gen_values($this_key)]
      if {$count ne ""} {
        if {$count != $this_count} {
          puts "mismatched list sizes... taking the lesser"
          if {$this_count < $count} {
            set count $this_count
          }
        } else {
          #counts match
        }
      } else {
        set count $this_count
      }
    }
    parray gen_values
  } else {
    set count 1
  }
  #populate template for each count
  puts "\nfinished config:"
  set config [dict get $yaml_in config]
  for {set x 0} {$x < $count} {incr x} {
    #import current list values into this variable space
    foreach this_key [array names gen_values] {
      set $this_key [lindex $gen_values($this_key) $x]
    }
    puts [subst $config]
  }
}
