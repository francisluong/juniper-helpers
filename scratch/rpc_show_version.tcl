#!/usr/bin/env tclsh
package require JuniperConnect
import_userpass "~/userpass"
set router 192.168.1.31
connectssh $router netconf
send_rpc $router [build_rpc "get-software-information"]

