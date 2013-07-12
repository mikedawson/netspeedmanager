#!/bin/bash

#
# Generates the report for how much bandwidth a user has consumed by listing
# the sites that have used the most bandwidth
#

USERNAME=$1

TIMEBACK=$2

/usr/lib/bwlimit/userbwreport.pl $USERNAME $TIMEBACK > /tmp/$USERNAME-bandwidth.log
/usr/lib/bwlimit/tsrg/top-sites-size-guilt-report.pl /tmp/$USERNAME-bandwidth.log /tmp/$USERNAME-bandwidth-report.html

rm /tmp/$USERNAME-bandwidth.log
cat /tmp/$USERNAME-bandwidth-report.html
rm /tmp/$USERNAME-bandwidth-report.html

