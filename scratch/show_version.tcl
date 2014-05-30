#!/usr/bin/env tclsh
package require JuniperConnect
import_userpass "~/userpass"
set router 192.168.1.31
connectssh $router
send_textblock $router "show version"

