#!/bin/bash

echo "Setting up from MESD blacklist database"

mkdir -p /tmp/squidguardbl
cd /tmp/squidguardbl

wget http://squidguard.mesd.k12.or.us/blacklists.tgz

tar -xzf blacklists.tgz

if [ ! -e /usr/local/squidGuard/db ]; then
	mkdir -p /usr/local/squidGuard/db
fi

if [ ! -e /usr/local/squidGuard/log ]; then
	mkdir -p /usr/local/squidGuard/log
	chown squid /usr/local/squidGuard/log
fi

echo "Made /usr/local/squidGuard/db"

mv blacklists/* /usr/local/squidGuard/db/

echo "Compile all blacklists"
/usr/bin/squidguard -b -c /etc/squid/squidguard.conf -C all
echo "Done"

chown squid /usr/local/squidGuard/db -R

rm -rf /tmp/squidguardbl

echo "All Done"

