#!/bin/bash

#
# Cleanup old runs
#
for x in `ls -d /tmp/bwlimit-cache-primer*`; do
	rm -rf $x
done


