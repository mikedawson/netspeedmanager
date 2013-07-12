#!/usr/bin/perl -wT

#
# This will be a perl script that will open up the config database and set
# all of the bandwidth limits (groups and users) according to the values there.
#
# This is by default as generous as possible; e.g. users will get the highest
# quota out of the groups that they are members of, or if their individual
# quota is higher then that one will be used
#

use strict;
use warnings;


use esmith::bwlimit::bwlimit_utils;
use esmith::FormMagick;
use esmith::AccountsDB;
use esmith::ConfigDB;

use DBI;
use DBD::mysql;

#Required to handle large quotas...
use Math::BigInt;



#MySQL stuff

my $db_name = "bwlimits";
my $db_user = "bwlimit";
open CFGFILE, "</etc/bwlimit.pw" or die $!;
my @cfglines = <CFGFILE>;
my $db_pass = $cfglines[1];
chomp($db_pass);
my $dsn = "dbi:mysql:$db_name:localhost:3306";

our $DBIconnect = DBI->connect($dsn, $db_user, $db_pass) or die "Could not connect to DB";
print "Connected to DB\n";


our $db = esmith::ConfigDB->open();
our $adb = esmith::AccountsDB->open();

my $bwlimit_system_type_rec = $db->get("BWLimitSetupType");

my $bwlimit_main_rec = $db->get("BWLimit");


if ($bwlimit_system_type_rec) {
    my $system_type_setting = $bwlimit_system_type_rec->prop("type");
    my $exceedpolicy = $bwlimit_main_rec->prop("exceedpolicy");
    my $depriorate = $bwlimit_main_rec->prop("depriorate");
    my $query_sql = "UPDATE process_log SET setup_type = '$system_type_setting', depriorate = '$depriorate', exceedpolicy = '$exceedpolicy'";
    my $query_handle = $DBIconnect->prepare($query_sql);
    $query_handle->execute();
    print "Updated bwlimit system type to: " , $system_type_setting, "\n";
}

my $LocalIPAddrRec = $db->get("LocalIP");
my $LocalNetmaskRec = $db->get("LocalNetmask");
my $LocalIP = $LocalIPAddrRec->prop("type");
my $LocalNetmask = $LocalNetmaskRec->prop("type");

my $ip_query_sql = "UPDATE process_log SET local_ip = '$LocalIP', local_netmask = '$LocalNetmask'";
my $ip_query_handle = $DBIconnect->prepare($ip_query_sql);
$ip_query_handle->execute();
print "Updated Local IP $LocalIP and Netmask $LocalNetmask for Net Speed Manager\n";

