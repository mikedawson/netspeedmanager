#!/bin/sh
 
USERNAME="testuserabc_create"
PASSWORD="testuserpass"

PATH=/sbin/e-smith:$PATH

if db accounts get $USERNAME >/dev/null
then
    echo "$USERNAME already exists in the accounts database"
    db accounts show abc
    exit 1
fi

db accounts set $USERNAME user PasswordSet no
db accounts setprop abc FirstName Tester
db accounts setprop abc LastName $USERNAME
db accounts setprop abc EmailForward local

signal-event user-create $USERNAME


echo $PASSWORD | passwd --stdin $USERNAME



