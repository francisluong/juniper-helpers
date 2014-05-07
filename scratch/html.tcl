package provide html 1.0
package require Tcl 8.5

namespace eval ::html {
    #namespace export html::xxx
    
    variable buffer {}
       
    proc init {} {
    #DarkGreyBg:     555555
    #GreyBorder:     D4D4D4
        variable buffer
        set buffer {}
        lappend buffer "
        <html>
        <head>
            <style>
                body,p,h1,h2,h3,h4,table,td,th,ul,ol,textarea,input \{
                    font-family:verdana,helvetica,arial,sans-serif;
                \}
                body \{
                    font-size:13px;
                }
                h1 \{font-size:28px;margin-top:0px;font-weight:normal\}
                h2 \{font-size:22px;margin-top:10px;margin-bottom:10px;font-weight:normal\}
                h3 \{font-size:17px;font-weight:normal\}
                h4 \{font-size:12px;\}
                h5 \{font-size:11px;\}
                h6 \{font-size:10px;\}
                h1,h2,h3,h4,h5,h6 \{
                    background-color:transparent;color:#000000;
                \}
                table
                \{
                    border-collapse:collapse;
                    width:100%;
                \}
                th
                \{
                    color:#ffffff;
                    background-color:#555555;
                    border:1px solid #555555;
                    padding:3px;
                    vertical-align: top;
                    text-align:left;

                \}
                td
                \{
                    border:1px solid #d4d4d4;
                    padding:5px;
                    padding-top:7px;
                    padding-bottom:7px;
                    vertical-align:top;
                \}
            </style>
        </head>
        <body>"
    }

    proc finish {{clear ""}} {
        variable buffer
        lappend buffer "</body></html>"
        if {[string match -nocase "clear" $clear]} {
            set temp $buffer
            set buffer {}
            return [textproc::njoin $temp]
        } else {
            return [textproc::njoin $buffer]
        }
    }

    proc table_init {} {
        variable buffer
        lappend buffer "<table border=\"1\">"

    }

    proc table_finish {} {
        variable buffer
        lappend buffer "</table>"
    }

    proc tr {input_list {td "td"}} {
        variable buffer
        lappend buffer "<tr>"
        foreach item $input_list {
            lappend buffer "    <$td>$item</$td>"
        }
        lappend buffer "</tr>"
    }

    proc _tagit {textblock tag} {
        variable buffer
        lappend buffer "<$tag>"
        lappend htmlparts "<$tag>"
        lappend buffer "    $textblock"
        lappend buffer "</$tag>"
    }

    proc pre {textblock} {
        set tag "pre"
        return [html::_tagit $textblock $tag]
    }

    proc h1 {textblock} {
        set tag "h1"
        return [html::_tagit $textblock $tag]
    }

    proc h2 {textblock} {
        set tag "h2"
        return [html::_tagit $textblock $tag]
    }

    proc h3 {textblock} {
        set tag "h3"
        return [html::_tagit $textblock $tag]
    }

    proc h4 {textblock} {
        set tag "h4"
        return [html::_tagit $textblock $tag]
    }

    proc p {textblock} {
        set tag "p"
        return [html::_tagit $textblock $tag]
    }

    proc ol {input_list {tag "ol"}} {
        return [html::ul $input_list $tag]
    }

    proc ul {input_list {tag "ul"}} {
        variable buffer
        set htmlparts {}
        lappend buffer "<$tag>"
        lappend htmlparts "<$tag>"
        foreach item $input_list {
            lappend htmlparts [html::li $item]
        }
        lappend buffer "</$tag>"
        lappend htmlparts "</$tag>"
        return [textproc::njoin $htmlparts]
    }

    proc li {list_item_text} {
        variable buffer
        set tag "li"
        set thistext "<$tag>$list_item_text</$tag>"
        lappend buffer $thistext
        return $thistext
    }

}
#namespace import html::*
