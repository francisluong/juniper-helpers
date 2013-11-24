
Script Information
==================
NAME: task-mem.slax
VERSION: 1.0
PURPOSE: task-mem.slax - Write the value of current task memory utilization (kB)
*          to snmp every 5 minutes
AUTHOR: Francis Luong (Franco) -- @francisluong - http://about.me/francisluong

The following OID in the Utility MIB is used by this script:
  *  jnxUtilIntegerValue.116.97.115.107.109.101.109
  *  jnxUtilIntegerValue.t.a.s.k.m.e.m

Instructions
============

1. Copy the file to /var/db/scripts/event on each routing-engine
2. Add the following configuration to the router:

  event-options {
    event-script {
      file task-mem.slax;
    }
  }

