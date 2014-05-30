#!/usr/bin/env tclsh
package require test
init_logfile "results.txt"
import_userpass "~/userpass"
set router 192.168.1.31
test::start "Sample Test"
test::subcase "Verify FPC 0 is Present"
test::analyze_output $router "show chassis hardware"
test::assert "FPC 0"
test::end_analyze
test::finish

