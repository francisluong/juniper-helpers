package provide ezhtml 1.0
package require Tcl 8.5
package require tdom

namespace eval ::ezhtml {
    #namespace export ezhtml::xxx
    
    variable stylesheet [string trim "
        body,p,h1,h2,h3,h4,table,td,th,ul,ol,textarea,input \{
            font-family:verdana,helvetica,arial,sans-serif;
        \}
        body \{
            font-size:13px;
        \}
        h1 \{font-size:28px;margin-top:0px;font-weight:normal\}
        h2 \{font-size:22px;margin-top:10px;margin-bottom:10px;font-weight:normal\}
        h3 \{font-size:17px;font-weight:normal\}
        h4 \{font-size:12px;\}
        h5 \{font-size:11px;\}
        h6 \{font-size:10px;\}
        h1,h2,h3,h4,h5,h6 \{
            background-color:transparent;color:#000000;
        \}
        table \{
            border-collapse:collapse;
            width:100%;
        \}
        th \{
            color:#ffffff;
            background-color:#555555;
            border:1px solid #555555;
            padding:3px;
            vertical-align: top;
            text-align:left;

        \}
        td \{
            border:1px solid #d4d4d4;
            padding:5px;
            padding-top:7px;
            padding-bottom:7px;
            vertical-align:top;
        \}
    "]
    variable domdoc {}
    variable head {}
    variable body {}
    variable lastnode {}
    variable tablenode {}

       
    proc init {{title ""}} {
    #DarkGreyBg:     555555
    #GreyBorder:     D4D4D4
        variable domdoc
        variable head
        variable body
        variable stylesheet
        variable lastnode
        if {$domdoc ne ""} {
            $domdoc delete
            set domdoc ""
        }
        set domdoc [dom createDocument "html"]
        set html [$domdoc documentElement]
        #add head
        set head [$domdoc createElement "head"]
        $html appendChild $head
        #add title to head if applicable
        if {$title ne ""} {
            set titletag [$domdoc createElement "title"]
            $head appendChild $titletag
            set titletextnode [$domdoc createTextNode $title]
            $titletag appendChild $titletextnode
        }
        #add stylesheet to head
        set stylenode [$domdoc createElement "style"]
        set styletextnode [$domdoc createTextNode $stylesheet]
        $stylenode appendChild $styletextnode
        $head appendChild $stylenode
        #add body to doc
        set body [$domdoc createElement "body"]
        $html appendChild $body
        set lastnode $body
        return [$domdoc asHTML]
    }

    proc finish {{clear ""}} {
        variable domdoc
        variable head
        variable body
        variable lastnode
        set html [$domdoc asHTML]
        $domdoc delete
        set domdoc {}
        set tablenode {}
        set head {}
        set body {}
        set lastnode {}
        return $html
    }

    proc _tagit {textblock tag} {
        variable domdoc
        variable body
        variable lastnode
        set thisnode [$domdoc createElement $tag]
        $body appendChild $thisnode
        set thistextnode [$domdoc createTextNode $textblock]
        $thisnode appendChild $thistextnode
        set lastnode $thisnode
        return [$thisnode asHTML]
    }

    proc pre {textblock} {
        set tag "pre"
        return [[namespace current]::_tagit $textblock $tag]
    }

    proc h1 {textblock} {
        set tag "h1"
        return [[namespace current]::_tagit $textblock $tag]
    }

    proc h2 {textblock} {
        set tag "h2"
        return [[namespace current]::_tagit $textblock $tag]
    }

    proc h3 {textblock} {
        set tag "h3"
        return [[namespace current]::_tagit $textblock $tag]
    }

    proc h4 {textblock} {
        set tag "h4"
        return [[namespace current]::_tagit $textblock $tag]
    }

    proc p {textblock} {
        set tag "p"
        return [[namespace current]::_tagit $textblock $tag]
    }

    proc ol {input_list {tag "ol"}} {
        return [[namespace current]::ul $input_list $tag]
    }

    proc ul {input_list {tag "ul"}} {
        variable domdoc
        variable body
        variable lastnode
        #create/append list
        set listnode [$domdoc createElement $tag]
        $body appendChild $listnode
        foreach item $input_list {
            # create/append items to list
            set itemnode [$domdoc createElement "li"]
            $listnode appendChild $itemnode
            set itemtextnode [$domdoc createTextNode $item]
            $itemnode appendChild $itemtextnode
        }
        set lastnode $listnode
        return [$listnode asHTML]
    }

    proc table_init {} {
        variable tablenode
        variable domdoc
        variable body
        variable lastnode
        #create/append table
        set tag "table"
        set tablenode [$domdoc createElement $tag]
        $tablenode setAttribute "border" 1
        $body appendChild $tablenode
        set lastnode $tablenode
        return [$tablenode asHTML]
    }

    proc table_finish {} {
        variable tablenode
        variable lastnode
        #really... set lastnode and return html... do nothing
        set lastnode $tablenode
        return [$tablenode asHTML]
    }

    proc table_header {input_list {th "th"}} {
        return [[namespace current]::tr $input_list $th]
    }
    proc th {input_list {th "th"}} {
        return [[namespace current]::tr $input_list $th]
    }

    proc table_row {input_list {td "td"}} {
        #alias tr
        return [[namespace current]::tr $input_list $td]
    }
    proc tr {input_list {td "td"}} {
        variable tablenode
        variable domdoc
        variable lastnode
        #create/append table row
        set tag "tr"
        set rownode [$domdoc createElement $tag]
        $tablenode appendChild $rownode
        foreach item $input_list {
            # create/append items to table
            set itemnode [$domdoc createElement $td]
            $rownode appendChild $itemnode
            set itemtextnode [$domdoc createTextNode $item]
            $itemnode appendChild $itemtextnode
        }
        set lastnode $rownode
        return [$rownode asHTML]
    }

}
#namespace import ezhtml::*
