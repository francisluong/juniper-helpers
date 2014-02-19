Examples
===========

userpass
--------
A sample username/password file.  One line each, username comes first.

001_basic.tcl
-------------
A simple test... login to a router, verify that the Chassis is either JunosV or MX. Saves a results file to /var/tmp/results.

002_display_xml_rpc.tcl
-----------------------
Takes a router, userpass file, and a command... provides the XML-RPC equivalent

lab@R1> show chassis hardware detail | display xml rpc
```xml
  <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X46/junos">
      <rpc>
          <get-chassis-inventory>
                  <detail/>
          </get-chassis-inventory>
      </rpc>
      <cli>
          <banner></banner>
      </cli>
  </rpc-reply>
```

003_netconf_basic.tcl
---------------------

A netconf variant on a simple testcase. Login to a router as netconf, verify that the Chassis is either JunosV or MX. Saves a results file to /var/tmp/results.

