#!/bin/bash

# Helper script to be called by deprio cmd chain in bwlimit-functions

IP=$1
USERNAME=$2

MARKERFILE=$(ls /var/current_BWL_clients/$IP-*)
if [ -e $MARKERFILE ]; then
	echo $USERNAME > $MARKERFILE
else
        echo "Eh - marker file does not exist - something weird going on"
fi

