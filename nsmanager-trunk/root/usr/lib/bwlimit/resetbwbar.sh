#!/bin/bash

DLSPEED=$(/sbin/e-smith/db configuration get BWLimitDownloadSpeed)
ULSPEED=$(/sbin/e-smith/db configuration get BWLimitUploadSpeed)

killall bwbar
#downloading
BWLIMITBASE=/usr/lib/bwlimit
echo "DL SPEED $DLSPEED"
echo "UL SPEED $ULSPEED"
$BWLIMITBASE/bwbar -t 30 -p $BWLIMITBASE/web/downbar.png -f $BWLIMITBASE/web/downbar.txt -x 300 -y 20 --kbps eth0 $DLSPEED &2>1 >/dev/null
$BWLIMITBASE/bwbar -t 30 -p $BWLIMITBASE/web/upbar.png -f $BWLIMITBASE/web/upbar.txt -x 300 -y 20 --input --kbps eth0 $ULSPEED &2>1 >/dev/null

echo "done"
