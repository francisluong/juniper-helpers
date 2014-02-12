#!/usr/bin/env tclsh

set auto_path [linsert $auto_path 0 "/home/fluong/code/juniper-helpers"]
package require test
package require tdom

#copied directly from https://github.com/Juniper/ncclient/blob/master/ncclient/xml_.py
set xslt_remove_namespace {
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="no"/>

  <xsl:template match="/|comment()|processing-instruction()">
      <xsl:copy>
          <xsl:apply-templates/>
      </xsl:copy>
  </xsl:template>

  <xsl:template match="*">
      <xsl:element name="{local-name()}">
          <xsl:apply-templates select="@*|node()"/>
      </xsl:element>
  </xsl:template>

  <xsl:template match="@*">
      <xsl:attribute name="{local-name()}">
          <xsl:value-of select="."/>
      </xsl:attribute>
  </xsl:template>
</xsl:stylesheet>
}


init_logfile "/var/tmp/results"
#usage
if {$argc < 2} {
  puts "Usage: [info script] <router_address> <path_to_userpass_file>"
  exit
} 
set router [lindex $argv 0]
import_userpass [lindex $argv 1]
puts "r_username: '$juniperconnect::r_username'"

test::start "netconf connect"

  juniperconnect::connectssh $router "netconf"
  set hello [juniperconnect::get_hello $router]
  #parse xml and get session id
  set root [dom parse $hello]
  set node [$root selectNodes "hello/session-id/text()"]

  h2 "parse session id"
  print "root: $root"
  print "node: $node"
  set session_id [$node data]
  test::analyze_textblock "Netconf Hello Contents" $hello
  print " - Acquired Session ID: $session_id"
  test::assert $session_id
  test::end_analyze

  h2 "netconf version"
  set rpc [juniperconnect::build_rpc $router "get-software-information"]
  print $rpc
  set output [send_rpc $router $rpc]
  set doc [dom parse $output]
  print [$doc asXML]
  print "doc: $doc"
  set root [$doc documentElement]
  set space [$root getAttribute xmlns]
  print "root xmlns=$space"
  $doc selectNodesNamespaces [list j $space]
  set node [$root selectNodes "j:software-information/j:host-name/text()"]
  print "node: $node"
  print [$node data]

  h2 "remove namespaces"
  set remove_namespaces [dom parse $xslt_remove_namespace]
  $doc xslt $remove_namespaces cleandoc
  print [$cleandoc asXML]

  h2 "craft a request for get-chassis-inventory/detail"
  set rpc [juniperconnect::build_rpc $router "get-chassis-inventory/detail"]
  print $rpc
  set output [send_rpc $router $rpc]
  set doc [dom parse $output]
  print "doc: $doc"
  set root [$doc documentElement]
  print "root: $root"
  print [$root asXML]
  print "current node: [$root nodeName]"
  set child [$root childNodes]
  print "child node(s): [$child nodeName]"
  print "child attribute(xmlns): [$child getAttribute xmlns]"
  set node [$root selectNodes "child::*"]
  print "node: $node"
  $doc selectNodesNamespaces [list j "http://xml.juniper.net/junos/12.1X46/junos-chassis"]
  set node [$root selectNodes "j:chassis-inventory/j:chassis/j:serial-number/text()"]
  #set node [$root selectNodes "//j:serial-number/text()"]
  print "node: $node"
  set chassis_serial [$node data]
  print ">>> chassis_serial: $chassis_serial"



test::finish
