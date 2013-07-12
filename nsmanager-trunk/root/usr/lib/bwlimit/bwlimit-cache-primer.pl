#!/usr/bin/perl -w
use strict;
use warnings;


use esmith::bwlimit::bwlimit_utils;
use esmith::FormMagick;
use esmith::AccountsDB;
use esmith::ConfigDB;


use DBI;
use DBD::mysql;

our $db = esmith::ConfigDB->open();
our $adb = esmith::AccountsDB->open();


#MySQL stuff

my $db_name = "bwlimits";
my $db_user = "bwlimit";
open CFGFILE, "</etc/bwlimit.pw" or die $!;

my @cfglines = <CFGFILE>;
my $db_pass = $cfglines[1];
chomp($db_pass);
my $dsn = "dbi:mysql:$db_name:localhost:3306";

our $DBIconnect = DBI->connect($dsn, $db_user, $db_pass) or die "Could not connect to DB";




my $localip = $db->get("LocalIP")->value;

print "Local ip = " . $localip;

#delete our old stuff
system("/usr/lib/bwlimit/bwlimit-cache-primer-cleanup.sh");

# Make the list of sites...
system("/usr/lib/bwlimit/tsrg/top-sites-size-plain.pl");

#set it to go through the proxy
$ENV{'http_proxy'} = "http://" . $localip . ":3128/";

#TODO: Use the config management system to set the timeout (mins)
my $timeout = 5;

my $bwlimit_system_type_rec = $db->get("BWLimitSetupType");

#in control panel is in kbps.  In wget is in KBs
my $xfer_rate_cap = int($db->get_prop("BWLimit", "CachePrimerSpeedLimit"))/8;
$xfer_rate_cap = $xfer_rate_cap . "k";

#now call wget to go through the list and pre-cache
my $timestamp = time();
my $dirname = "/tmp/bwlimit-cache-primer-" . $timestamp; 

mkdir($dirname);
chdir($dirname);

my $output = `wget --output-file /usr/lib/bwlimit/wget-cache-prime.log --background -i /usr/lib/bwlimit/top-sites-size.htm  --limit-rate=$xfer_rate_cap --page-requisites  --html-extension  --convert-links  --span-hosts  --no-check-certificate -e robots=off  --accept=css,jpg,gif,png,jpeg,js --delete-after`;
$output =~ m/pid (\d+)\./;
my $pid = $1;

#delete old stuff
my $sql_update1 = "Delete from bwlimit_cache_primer";
my $query_handle1 = $DBIconnect->prepare($sql_update1);
$query_handle1->execute();

my $sql_update2 = "Insert into bwlimit_cache_primer (pid, time_started) values ($pid, $timestamp)";
my $query_handle2 = $DBIconnect->prepare($sql_update2);
$query_handle2->execute();



