Examples
===========

userpass
--------
A sample username/password file.  One line each, username comes first.

```
username
password
```

001_basic.tcl
-------------

```
Usage: ./001_basic.tcl <router_address> <path_to_userpass_file>
```

A simple test... login to a router, verify that the Chassis is either JunosV or MX. Saves a results file to /var/tmp/results.

002_display_xml_rpc.tcl
-----------------------

```
Usage: ./002_display_xml_rpc.tcl <router_address> <path_to_userpass_file> <command>
```

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

```
Usage: ./003_netconf_basic.tcl <router_address> <path_to_userpass_file>
```

A netconf variant on a simple testcase. Login to a router as netconf, verify that the Chassis is either JunosV or MX. Saves a results file to /var/tmp/results.

100_yaml_config_template.tcl
-----------------------------

```
Usage: ./100_yaml_config_template.tcl <path_to_YAML_file - e.g. 101_misc_examples_template.yml>
```

Takes a command-line argument: path to a yaml file which specifies the config to be generated.  An [example](https://github.com/francisluong/juniper-helpers/blob/master/examples/101_misc_examples_template.yml) is provided.  Outputs the [generated configuration](https://github.com/francisluong/juniper-helpers/blob/master/examples/101_misc_examples_template.yml.output.txt) to stdout.

 * 101_misc_examples_template.yml - misc examples covering the range of generation options
 * 102_template_vpn_l2circuit.yml - 40 l2circuit configs for both PEs
 * 103_template_vpn_l3vpn.yml - 20 l3vpn interfaces and instances

