package provide output 1.1
package require Tcl 8.5
package require textproc

### This package provides concise syntax for output and logging

namespace eval ::output {

    namespace export h1 h2 indent blockanchor lineanchor init_logfile \
        print printline

    variable width 60
        #width for dash marks
    variable logfile ""
    variable logfile_active 0
    variable quiet_stdout 0
    variable default_indent_count 4

    proc init_logfile {filepath} {
        ### activate logging to file
        set output::logfile $filepath
        set output::logfile_active 1
        output::log_results_clear $filepath
    }

    proc log_results_clear {target_filepath} {
        ### internal: used to rotate an existing logfile
        set suffix "bak"
        if {[string match "*/*" $target_filepath]} {
            # filepath contains at least one slash
            set filename [file tail $target_filepath]
            # extract path
            set path [file dirname $target_filepath]
        } else {
            # filepath doesn't have any slashes... set path to local folder
            set filename $target_filepath
            set path {.}
        }
        if {[file exists $target_filepath]} {
            # if filepath exists, we rotate it by adding timestamp and .bak
            set format_string "%G-%m%d-%H%M"
            file stat $target_filepath "time"
            set formatted_timestamp [clock format $time(ctime) \
                -format $format_string]
            set filename "${path}/${filename}.${formatted_timestamp}.${suffix}"
            set catch_result [ catch {file rename $target_filepath $filename} ]
        }
        # start a new file
        set fname [open $target_filepath w]
        # ...and close it
        close $fname
        return $filename
    }


    proc h1 {text {indent_space_count "0"} {screenonly "0"}} {
        # output a Level 1 Header
        #   for info on indent_space_count and screenonly see proc print
        set this_text [output::format_header $text "=" \
            $indent_space_count "uppercase"]
        return [output::print $this_text $indent_space_count $screenonly]
    }

    proc h2 {text {indent_space_count "2"} {screenonly "0"}} {
        # output a Level 2 Header
        #   for info on indent_space_count and screenonly see proc print
        set this_text [output::format_header $text "-" \
        $indent_space_count]
        return [output::print $this_text $indent_space_count $screenonly]
    }

    proc print {text {indent_space_count "default"} {screenonly "0"}} {
        # output text to screen unless screenonly is 1
        #   if logfile is active, output to active log file
        #   output will be indented per $indent_space_count
        variable logfile_active
        variable logfile
        variable quiet_stdout
        if {$indent_space_count eq "default"} {
            # use default indent
            variable default_indent_count
            set indent_space_count $default_indent_count
        }
        if {$text ne ""} {
            # indent text and store in $this_text
            set this_text [output::indent $text $indent_space_count]
            # output to file if file is active and screenonly == 0
            if {$logfile_active && $screenonly == "0"} {
                set filepath $logfile
                set fname [open $filepath a]
                puts $fname $this_text
                close $fname
            }
            # output to screen if not suppressed by quiet_stdout == 1
            if {!$quiet_stdout} {
                foreach line [textproc::nsplit $this_text] {
                    puts $line
                    after 1
                }
            }
        } else {
            # text is empty - do nothing except return it
            set this_text $text
        }
        # we return indented text
        return $this_text
    }

    proc printline {{indent_space_count "default"} {screenonly "0"}} {
        # output dash marks
        if {$indent_space_count eq "default"} {
            variable default_indent_count
            set indent_space_count $default_indent_count
        }
        set line [output::hr "-" $indent_space_count]
        return [output::print $line $indent_space_count $screenonly]
    }

    proc hr {dashmark {indent_space_count 0}} {
        # generate a line of dashmarks
        set linecount [expr $output::width - $indent_space_count]
        set line [string repeat $dashmark $linecount]
        return $line
    }

    proc format_header {text dashmark {indent_space_count 0} {uppercase 0}} {
        # internal: used to dress up our headers
        if {$uppercase ne "0"} {
            set text [string toupper $text]
        }
        set line [output::hr $dashmark $indent_space_count]
        set result_textblock {}
        foreach item [list $line $text $line] {
            append result_textblock "\n"
            append result_textblock $item
        }
        return [output::indent $result_textblock $indent_space_count]
    }

    proc indent {text num_spaces} {
        # indent lines of text
        set newtext {}
        foreach line [textproc::nsplit $text] {
            #don't indent empty lines
            if {$line eq ""} {
                lappend newtext ""
            #but do indent the ones that have content
            } else {
                lappend newtext "[string repeat " " $num_spaces]$line"
            }
        }
        return [join $newtext "\n"]
    }

    proc blockanchor {text} {
        # add anchors to text line-before and line-after
        return ">>>>\n$text\n<<<<"
    }

    proc lineanchor {text} {
        # add left-right anchors for each line of text to see whitespace
        set result {}
        foreach line [textproc::nsplit $text] {
            lappend result ">$line<"
        }
        return [textproc::njoin $result]
    }

    variable output_buffer ""

    proc buffer {text} {
        # tuck text away in a buffer to output later
        lappend output::output_buffer $text
    }

    proc buffer_clear {} {
        # re-initialize the buffer
        set output::output_buffer ""
    }

    proc buffer_print {{indent_space_count "default"} {clear ""}} {
        # output the contents of the buffer
        #   if clear is not set to "", it will also call buffer_clear
        output::print [textproc::njoin $output::output_buffer] $indent_space_count
        if {[string match -nocase "clear" $clear]} {
            output::buffer_clear
        }
    }

    proc buffer_get {{clear ""}} {
        # return, but do not output, the contents of the buffer
        #   if clear is not set to "", it will also call buffer_clear
        set buffer_contents [textproc::njoin $output::output_buffer]
        if {[string match -nocase "clear" $clear]} {
            output::buffer_clear
        }
        return $buffer_contents
    }

    proc pdict { dictVarName {indent 1} {prefixString "    "} {separator " => "} } {
    # pretty-print a dict
    #copied from http://wiki.tcl.tk/23526...
    # alterations by @francisluong
        set fRepExist [expr {0 < [llength\
                        [info commands tcl::unsupported::representation]]}]
        #output dictionary name if first iteration
        if { (![string is list $dictVarName] || [llength $dictVarName] == 1)
                        && [uplevel 1 [list info exists $dictVarName]] } {
                set dictName $dictVarName
                unset dictVarName
                upvar 1 $dictName dictVarName
                puts "dict $dictName"
        }
        #throw an exception if we are not dealing with a key value list
        if { ! [string is list $dictVarName] || [llength $dictVarName] % 2 != 0 } {
                return -code error  "error: pdict - argument is not a dict"
        }
        set prefix [string repeat $prefixString $indent]
        #set max to the string length of the longest key
        set max 0
        foreach key [dict keys $dictVarName] {
            if { [string length $key] > $max } {
                set max [string length $key]
            }
        }
        #output keys at this level and call pdict for inside levels
        dict for {key val} ${dictVarName} {
            puts -nonewline "$indent:${prefix}[format "%-${max}s" $key]$separator"
            if {    $fRepExist && [string match "value is a dict*"\
                    [tcl::unsupported::representation $val]]
                    || ! $fRepExist && [string is list $val]
                    && [llength $val] % 2 == 0 } {
                #it's a dict... recurse!
                puts ""
                pdict $val [expr {$indent+1}] $prefixString $separator
            } else {
                #scalar value... print and return
                puts "'${val}'"
            }
        }
        return
    }

}

namespace import output::*
