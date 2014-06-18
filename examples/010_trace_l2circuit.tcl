#!/usr/bin/env tclsh

package require test
package require gen

juniperconnect::quiet


proc check_interface {router interface_name} {
    set rpc [juniperconnect::build_rpc "get-interface-information/interface-name='$interface_name'"]
    test::analyze_netconf $router $rpc
    test::xassert "//input-packets/text()" "compare" "!=" "0"
    test::xassert "//output-packets/text()" "compare" "!=" "0"
    test::end_analyze "ascii"
}

proc check_l2circuit {router interface_name} {
    set rpc [juniperconnect::build_rpc "get-l2ckt-connection-information/interface='$interface_name'"]
    set output [test::analyze_netconf $router $rpc]
    test::xassert "//connection-status/text()" "regexp" "Up"
    test::xassert "//local-interface/interface-status/text()" "regexp" "Up"
    test::end_analyze "ascii"
    set results_dict ""
    dict set results_dict "remote_router" [string trim [textproc::get_xml_text $output "//remote-pe"]]
    set full_connection_id [string trim [textproc::get_xml_text $output "//connection-id"]]
    dict set results_dict "connection_id" $full_connection_id
    set connection_id [string trim [lindex $full_connection_id end] ")"]
    dict set results_dict "vcid" $connection_id
    return $results_dict
}

proc get_l2circuit_config_xml {router remote_router} {
    set rpc [build_rpc "get-config/source/running"]
    set rpc [add_to_rpc $rpc \
        "get-config/filter,@type='subtree'/configuration/protocols/l2circuit/neighbor/name='$remote_router'"]
    return [send_rpc $router $rpc]
}

proc get_l2circuit_interface_by_vcid {router remote_router vcid} {
    set xml_out [get_l2circuit_config_xml $router $remote_router]
    set interfaces [textproc::get_xml_text $xml_out \
        "//interface\[virtual-circuit-id='$vcid'\]/name/text()"]
    return $interfaces
}

#usage
if {$argc < 3} {
  puts "Usage: [info script] <path_to_userpass_file> <router> <interface.unit> \[<interface.unit>...]"
  exit
} 
import_userpass [lindex $argv 0]
set formatted_timestamp [gen::datetime]
init_logfile "./[file tail $argv0].results.$formatted_timestamp.txt"


set router [lindex $argv 1]

output::h1 "args"
output::print "$argv0 $argv"
set interface_list [lrange $argv 2 end]
foreach interface $interface_list {
    output::h1 "PW Trace: $router $interface"
    if {![string match -nocase "*.*" $interface]} {
        output::print "Interface Invalid: '$interface'.  Check <interface.unit> and try again"
    } else {
        test::subcase "$interface: Local Interface Counters Non-Zero"
        check_interface $router $interface
        test::subcase "$interface: Local L2circuit Up"
        array unset params 
        array set params [check_l2circuit $router $interface]
        #parray params
        connectssh $params(remote_router) "netconf"
        set params(remote_interface) [get_l2circuit_interface_by_vcid \
            $params(remote_router) $address $params(vcid)]
        test::subcase "$interface: Remote Interface Counters Non-Zero"
        check_interface $params(remote_router) $params(remote_interface)
        test::subcase "$interface: Remote L2Circuit Up"
        check_l2circuit $params(remote_router) $params(remote_interface)
    }
}
test::finish
