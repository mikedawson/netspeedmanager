%define name nsmanager
%define version 0.0.6
%define release 05	

Summary: SME Server Netspeed Manager Addon
Name: %{name}
Version: %{version}
Release: %{release}
License: Closed
Group: Networking/Daemons
Source: %{name}-%{version}.tar.gz
Packager: Mike Dawson <mike@toughra.com>
BuildRoot: /var/tmp/%{name}-%{version}-%{release}-buildroot
BuildArchitectures: noarch
AutoReqProv: no
Requires: squidguard
Requires: squid
Requires: dsniff
Requires: perl-IO-Interface

%description
nsm sample application.

%changelog
* Sun May 22 2011 Fred Frog <fred@example.com>
- 0.0.1-01
- Original version

%prep
%setup

%build
# $RPM_BUILD_ROOT/createlinks
perl createlinks
#echo $RPM_BUILD_ROOT
#read


%install
rm -rf $RPM_BUILD_ROOT
(cd root ; find . -depth -print | cpio -dump $RPM_BUILD_ROOT)
rm -f %{name}-%{version}-filelist
/sbin/e-smith/genfilelist $RPM_BUILD_ROOT > %{name}-%{version}-filelist

%clean
rm -rf $RPM_BUILD_ROOT

%post

/etc/e-smith/events/actions/initialize-default-databases
/sbin/e-smith/expand-template /etc/e-smith/sql/init/BWLimit-create-schema.sql
/etc/rc.d/init.d/mysql.init start

/sbin/e-smith/expand-template /etc/crontab
/sbin/e-smith/expand-template /etc/httpd/conf/httpd.conf
/sbin/e-smith/expand-template /etc/squid/squid.conf
/sbin/e-smith/expand-template /etc/nsm.conf.php
/sbin/e-smith/expand-template /etc/bwlimit.pw
/sbin/e-smith/expand-template /etc/squid/squidguard.conf
/sbin/e-smith/expand-template /etc/htb-gen/htb-gen.conf
/sbin/e-smith/expand-template /etc/rc.d/init.d/masq
/sbin/e-smith/expand-template /etc/pmacct/pmacctd.conf
/sbin/e-smith/expand-template /etc/httpd/conf/proxy/proxy.pac
/sbin/e-smith/expand-template /usr/lib/bwlimit/web/usergroups.xml
/sbin/e-smith/expand-template /usr/lib/bwlimit/cgi-bin/redir.pl
/sbin/e-smith/expand-template /etc/bwlimit_calcbandwidth
/sbin/e-smith/expand-template /etc/dhcpd.conf

#setup classids for all groups
/etc/e-smith/events/actions/bwlimit-init-group-classid

#init default lists etc
/usr/lib/bwlimit/initdefaultfiles

#check on the database
/usr/lib/bwlimit/upgrade-0.0.3-checkdb.php
/usr/lib/bwlimit/upgrade-0.0.4-checkdb.php

/etc/e-smith/events/actions/navigation-conf

#handle squid cache directories
/usr/bin/sv stop squid
/usr/sbin/squid -z
/usr/bin/sv start squid

/usr/bin/sv t httpd-e-smith
/usr/bin/sv t dhcpd
/etc/init.d/crond restart

/bin/chgrp www /usr/lib/bwlimit/netspeedmanager_ipcontrol
/bin/chmod 4755 /usr/lib/bwlimit/netspeedmanager_ipcontrol
/bin/chmod 4755 /usr/lib/bwlimit/netspeedmanager_killclient
/bin/chmod 4755 /usr/lib/bwlimit/netspeedmanager_deliverdownload
/sbin/e-smith/db configuration setprop bwlimit_startup status enabled 
/sbin/e-smith/db configuration setprop nsmcalcbytes status enabled



chown smelog:smelog /var/log/nsmcalcbytes
chown smelog:smelog /var/log/nsmdhcpsec

/usr/bin/sv start nsmcalcbytes
/usr/bin/sv start nsmdhcpsec

#Fix squid pam perimssion
chmod 4755 /usr/lib/squid/pam_auth
/usr/lib/bwlimit/bwlimit-computequotas.pl

touch /var/log/squid/squidguard.log
chown squid:squid /var/log/squid/squidguard.log

true

%postun
/sbin/e-smith/expand-template /etc/crontab
/sbin/e-smith/expand-template /etc/httpd/conf/httpd.conf
/sbin/e-smith/expand-template /etc/squid/squid.conf
/sbin/e-smith/expand-template /etc/rc.d/init.d/masq
/sbin/e-smith/expand-template /etc/dhcpd.conf
/etc/e-smith/events/actions/navigation-conf
true

/etc/init.d/crond restart

%files -f %{name}-%{version}-filelist
%defattr(-,root,root)

%preun
/usr/bin/sv stop nsmcalcbytes
/sbin/e-smith/expand-template /etc/rc.d/init.d/masq
/sbin/e-smith/expand-template /etc/httpd/conf/proxy/proxy.pac
/etc/init.d/masq restart



true
