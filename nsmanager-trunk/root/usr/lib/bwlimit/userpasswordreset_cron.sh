#!/bin/bash


#
# Args are : admin password, username, new user password
#
USERNAME=$1
USERPASS=$2

echo "$USERNAME:$USERPASS" | /usr/sbin/chpasswd


