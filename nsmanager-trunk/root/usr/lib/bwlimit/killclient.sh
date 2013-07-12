#!/bin/bash

# Wrapper to stop a given client

IPADDR=$1
IFACE=`/sbin/e-smith/db configuration getprop InternalInterface Name`

/usr/lib/bwlimit/cutter $IPADDR
/usr/lib/bwlimit/timelimit -T 6 -t 5 /usr/sbin/tcpkill -i $IFACE host $IPADDR 


