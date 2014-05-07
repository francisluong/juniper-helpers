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

    proc finish {} {
        variable buffer
        lappend buffer "</body></html>"
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

}
#namespace import html::*
