package provide delim 1.0
package require csv

namespace eval ::delim {
    #namespace export 

    variable byrow {}
    variable bycol {}

    proc import {delimited_table_text split_char} {
        set byrow {}
        set bycol {}
        array set columns {}
        #process delimited text into byrow and bycol namespace variables
        set rownum 0
        foreach line [split [string trim $delimited_table_text] "\n"] {
            set linesplit [delim::split_line $line $split_chars]
            lappend byrow $linesplit
            set colnum 0
            foreach item $linesplit {
                lappend columns($colnum) $item
                incr colnum
            }
            incr rownum
        }
        foreach colnum [lsort -integer [array names columns]] {
            lappend bycol $columns($colnum)
        }
        set delim_dict {}
        dict set delim_dict byrow $byrow
        dict set delim_dict bycol $bycol
        return $delim_dict
    }

    proc split_line {line_text split_char} {
        #split lines handling double-quoted sections - already handled by tcllib
        return [csv::split $line_text $split_char]
    }

    proc group_by_column {delim_dict key_column_number_from_zero value_column_number} {
        set byrow [dict get $delim_dict byrow]
        set number_of_columns [llength [lindex $byrow 0]]
        if {$key_column_number_from_zero >= $number_of_columns 
            || $key_column_number_from_zero < 0
            || $value_column_number < 0
            || $value_column_number >= $number_of_columns} {
            return -code error "[namespace current]::group_by_column: ERROR key or value column number out of range vs. # columns: key $key_column_number_from_zero value $value_column_number vs. $number_of_columns"
        }
        set key_valuelist_dict {}
        foreach rowlist $byrow {
            set key [lindex $rowlist $key_column_number_from_zero]
            set value [lindex $rowlist $value_column_number]
            dict lappend key_valuelist_dict $key $value
        }
        return $key_valuelist_dict
    }

    proc format {list_of_column_values delimiter} {
        #return a line of delimited text... "quote" any items that have \n or $delimiter 
    }

}

#namespace import delim::*

