#!/bin/bash

#
# This script will activate an IP and do the required IPTables rules
#

#whoami
#echo $UID
# usage: --activate|--deactivate IPADDRESS ratedown ceildown rateup ceilup nohttps username customhtbparent
#nohttps = 1 to block direct https (e.g. force use of proxy)
#customhtbparent htb parent custom id or 0 for none

#this argument is the either "--activate" or "--deactivate"
OPTION=$1

#the ip in question
IP=$2

#If we need to block direct https for this client (force to use squid so we can filter connect method)
NOHTTPS=$7

USERNAME=$8

#Custom HTB parent class id to pass - 0 for none
CUSTOMPARENT=$9

CALLER=$(readlink /proc/$PPID/exe)

PARENTPPID=$(ps -p $PPID -o ppid | tail -n 1 | tr -d ' ')

PARENTCALLER=$(readlink /proc/$PARENTPPID/exe)

echo "[ $(date) ] ipcontroxl called with args $@ by $CALLER (pid $PPID) and $PARENTCALLER (pid $PARENTPPID)" >> /var/log/nsmipctrl.log

if [ "foo$IP" == "foo" ]; then
    echo "Usage: netspeedmanager_ipcontrol --activate|--deactivate <ipaddr> rateup ratedown ceilup ceildown 0|1 username customhtbparent"
    exit
fi



if [ "foo$OPTION" == "foo--activate" ]; then
    #check and see if this client is already activated

    #Make sure that we dont have ip addresses matching that should not - e.g .20 and .201    
    IPTOUT=$(/sbin/iptables -t nat -L -n | grep MASQUERADE | grep " $IP ")
    if [ "foo$IPTOUT" == "foo" ]; then
	/sbin/iptables --insert PostroutingOutbound 3 -t nat -j MASQUERADE -s $IP 
        /sbin/iptables --table nat --insert TransProxy 4\
	        -p TCP -s $IP -j DNAT --to $(/sbin/e-smith/config get LocalIP):$(/sbin/e-smith/config getprop squid TransparentPort)
        /sbin/iptables --table nat --insert PreProxy 3 -p TCP -s $IP -j ACCEPT


	if [ "$NOHTTPS" == "1" ]; then
		/sbin/iptables --insert PostroutingOutbound 3 -t nat --proto tcp --dport 443 -j DROP -s $IP
	fi
    else
	echo "Masq for this client already active see"
    fi
    
        /usr/lib/bwlimit/htb-gen new_device $IP $3 $4 $5 $6 $CUSTOMPARENT $USERNAME
    
#    MARKERFILE=$(ls /var/current_BWL_clients/$IP-*)
#    if [ -e $MARKERFILE ]; then
#	echo $USERNAME > $MARKERFILE
#    else 
#	echo "Eh - marker file does not exist - something weird going on"
#    fi
else
    iptables --delete PostroutingOutbound -t nat -j MASQUERADE -s $IP
    /sbin/iptables --table nat --delete TransProxy \
    	-p TCP -s $IP -j DNAT --to $(/sbin/e-smith/config get LocalIP):$(/sbin/e-smith/config getprop squid TransparentPort)
    /sbin/iptables --table nat --delete PreProxy -p TCP -s $IP -j ACCEPT


    IPTOUT=$(/sbin/iptables -t nat -L -n | grep DROP | grep " $IP " )
    if [ "foo$IPTOUT" != "foo" ]; then
	iptables --delete PostroutingOutbound -t nat --proto tcp --dport 443 -j DROP -s $IP
    fi
    /usr/lib/bwlimit/htb-gen clear_device $IP $USERNAME
fi
