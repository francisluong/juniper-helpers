#!/usr/bin/env tclsh

package require rpc
package require tcloo

rpc::new req1
req1 attrib id 100
req1 edit "this/that/theother"
puts [req1 pretty]

rpc::new req2
req2 attrib id 101
req2 edit "get-mpls-lsp-information"
req2 add ingress
req2 add detail
req2 add regex "BOB"
puts [req2 pretty]

req1 reset
req1 attrib id 102
req1 edit "this2/that2"
req1 up
req1 add "that3"
puts [req1 done]
puts [req1 pretty]
