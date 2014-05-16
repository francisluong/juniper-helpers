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

200_concurrency_ping.tcl
-----------------------------

```
Usage: ./200_concurrency_ping.tcl <targetAddress1> .. <targetAddressN>
```
Example script for concurrency package.  Launches a number of child processes to perform pings for the addresses supplied as arguments. A subscript is launched for each ping target and pings are run in parallel.  Results are retrieved and reported.


210_concurrency_push_config_yaml.tcl
-----------------------------

```
Usage: ./210_concurrency_push_config_yaml.tcl <userpass_file> <yaml_config_gen_file> <router1> [<router2>... <routerN>]
```
Example script for concurrency package.  Launches a number of child processes to apply router configuration generated from the specified yaml_config_gen_file.  A child script is launched for each router specified as an argument.


210_concurrency_push_config_yaml.tcl
-----------------------------

```
Usage: ./210_concurrency_push_config_yaml.tcl <userpass_file> <yaml_config_gen_file> <router1> [<router2>... <routerN>]
```
Example script for concurrency package.  Launches a number of child processes to apply router configuration generated from the specified yaml_config_gen_file.  A child script is launched for each router specified as an argument.

 * 211_enable_netconf_ssh.yml - generates config to enable netconf/ssh.


220_concurrent_show.tcl
-----------------------------

```
Usage: ./220_concurrent_show.tcl <path_to_userpass_file> router1 [...routerN]
```
Example script for the JuniperConnect package which demonstrates using juniperconnect::send_textblock_concurrent.  Launches a number of child processes to run two commands: "show version" and "show chassis hardware".  A child script is launched for each router specified as an argument.


221_concurrent_show_basic.tcl
-----------------------------

```
Usage: ./221_concurrent_show_basic.tcl <path_to_userpass_file> router1 [...routerN]
```
A version of 220_concurrent_show.tcl that does not use the juniperconnect concurrency hooks.


250_push_config_from_csv.tcl
-----------------------------

```
Usage: ./250_push_config_from_csv.tcl <userpass_file> <path_to_delim_config_file> <delimiter> [<router_column=0> <config_column=1>] [test]
```
A script that takes a CSV (comma separated value) file with a column that identifies routers and a column that specifies configuration commands.  Those columns can be any two in the file but the default assumes columns 0 and 1 (where 0 is leftmost).  The script will process the CSV file and spawn a process for each router identified to configure it in parallel.  Then it will report on the success of each configuration effort.
