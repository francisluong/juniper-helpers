
###############################################################################
# <!--------------- EZMAIL - email helper -------------->
###############################################################################
#
# Abstract
# ================
# helper procs that present an interface for TCLLIB mime/smtp that is consistent
# with my work flow
#
# Setting Up
# ==========
# set your from_email_address using ezmail::init
# if smtp server is not localhost... TBD

package provide ezmail 1.0
package require Tcl 8.5
package require mime
package require smtp

namespace eval ::ezmail {
  #generators of lists
  #namespace export XXX

  variable subject {}
  variable from_email_address "nobody@nobody.com"
  variable body_text {}
  variable mime_token_stack {}

  proc init {from_email_address} {
    set ezmail::from_email_address $from_email_address
  }

  proc start_message {tempfile_name subject_text} {
    variable body_text
    variable mime_token_stack 
    set body_text {}
    set mime_token_stack {}
    set ezmail::subject "$subject_text -- [clock format [clock seconds]]"
    package require mime
    package require smtp
  }

  proc add_body {textblock} {
    variable body_text
    if {$body_text ne ""} {
      append body_text "\n"
    }
    append body_text $textblock
  }

  proc add_attachment {textblock attachment_filename} {
    variable mime_token_stack
    set attachment_token [mime::initialize \
      -canonical "text/plain; name=\"$attachment_filename\"" \
      -encoding "base64" \
      -string $textblock ]
    lappend mime_token_stack $attachment_token
  }

  proc send_single {target_email_address multipart_token} {
    smtp::sendmessage $multipart_token \
      -header [list From [string trim $ezmail::from_email_address]] \
      -header [list To [string trim $target_email_address]] \
      -header [list Subject [string trim $ezmail::subject]]
  }

  proc send_email {target_email_list} {
    #build mime multipart
    set body_token [mime::initialize \
      -canonical "text/plain" \
      -encoding "base64" \
      -string $ezmail::body_text]
    variable mime_token_stack
    set mime_token_stack [linsert $mime_token_stack 0 $body_token]
    set multipart_token [mime::initialize \
      -canonical multipart/mixed \
      -parts $mime_token_stack]
    #send e-mails
    foreach target_email $target_email_list {
      puts "To: $target_email"
      send_single $target_email $multipart_token
    }
    puts "Subject: $ezmail::subject"
    puts "Email Content:"
    puts_slow [indent $ezmail::body_text 2]
    #clean up
    set ezmail::body_text {}
    mime::finalize $multipart_token -subordinates all
    set mime_token_stack {}
  }

}
#namespace import ezmail::*
