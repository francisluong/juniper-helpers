#!/usr/bin/env tclsh

package require JuniperConnect
package require output

set doc [juniperconnect::build_rpc "get-config/source/candidate"]
set doc [dom parse [juniperconnect::add_to_rpc $doc "get-config/filter,@type='subtree'/configuration/protocols/bgp"]]

puts [$doc asXML]
