#!/bin/bash

#
# INPUT - give dir timestamp
# 
TIMESTAMP=$1

WORKDIR="/tmp/bwlimit-cache-primer-$TIMESTAMP"
OUTFILE="/usr/lib/bwlimit/web/cache-prime-report.html"

if [ -e $OUTFILE ]; then
	rm $OUTFILE
fi

if [ -e $WORKDIR ]; then
	STARTSTR=$(echo $TIMESTAMP | awk '{print strftime("%c",$1)}')
	ENDSTR=$(echo $(date '+%s') | awk '{print strftime("%c",$1)}')

	echo "<html><body><h1>Cache Prime Report</h1>" >> $OUTFILE
	echo "Time Started: $STARTSTR <br/>" >> $OUTFILE
	echo "Time Ended: $ENDSTR <br/>" >> $OUTFILE
	echo "<h3>Sites Primed:</h3>" >> $OUTFILE
	echo "<ul>" >> $OUTFILE

	for x in `ls $WORKDIR`; do
		echo "<li>$x</li>" >> $OUTFILE
	done

	echo "</ul></body></html>" >> $OUTFILE
fi
