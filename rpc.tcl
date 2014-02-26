package provide rpc 1.0
package require Itcl
package require tdom

namespace eval ::rpc {
  itcl::class new {
    variable document
    variable context
    variable end_of_message {]]>]]>}

    constructor {} {
      variable document
      variable context
      set document [dom createDocument "rpc"]
      set context [$document documentElement]
    }

    method reset {} {
      variable document
      variable context
      set document [dom createDocument "rpc"]
      set context [$document documentElement]
    }

    method top {} {
      variable document
      variable context
      set context [$document documentElement]
    }

    method up {{levels 1}} {
      variable context
      for {set x 0} {$x < $levels} {incr x} {
        set context [$context parentNode]
      }
    }

    method edit {relative_path} {
      variable document
      variable context
      set relative_path [string trim $relative_path]
      foreach elementname [split $relative_path "/"] {
        set new_node [$document createElement $elementname]
        $context appendChild $new_node
        set context $new_node
      }
    }

    method add {elementname {value ""}} {
      variable document
      variable context
      set new_node [$document createElement $elementname]
      $context appendChild $new_node
      if {$value ne ""} {
        set text_node [$document createTextNode $value]
        $new_node appendChild $text_node
      }
    }

    method attribute {attributeName value} {
      return [attrib $attributeName $value]
    }
    method attrib {attributeName value} {
      variable context
      $context setAttribute $attributeName $value
    }

    method done {{indent "none"}} {
      variable document
      variable end_of_message 
      return "[$document asXML -indent $indent]$end_of_message"
    }

    method pretty {} {
      return "[done 2]\n"
    }

  }


}
