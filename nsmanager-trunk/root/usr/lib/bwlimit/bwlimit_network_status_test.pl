#!/usr/bin/perl -wT

#
# This script will test the status of the network connection, internet connection
# by checking pinging an IP and a hostname
#
# It will then record the result in a database so NSM webapps can access this as
# needed
#


use Net::Ping;

use esmith::bwlimit::bwlimit_utils;
use esmith::FormMagick;
use esmith::AccountsDB;
use esmith::ConfigDB;

use DBI;
use DBD::mysql;

my $db = esmith::ConfigDB->open();
my $gateway_record = $db->get("GatewayIP");
my $gateway_ip = $gateway_record->prop("type");
my $external_ip_record = $db->get("ExternalIP");
my $external_ip = $external_ip_record->prop("type");


#print "Try to p ing " . $gateway_ip . "\n";


#Try and check the gateway
my $p = Net::Ping->new("icmp");
my $status_gateway = $p->ping($gateway_ip, 3000);

print "Gatway is OK? : $status_gateway \n";


# now check the Internet Connection
# in this case the google DNS server
my $internet_ip = "8.8.8.8";
my $success_count = 0;
my $status_internet_ip = 0;
for(my $count = 0; $count < 4; $count++) {
    my $current_result = $p->ping($internet_ip, 3);
    if($current_result == 1) {
        $success_count = $success_count + 1;
    }
    print "Ping $internet_ip $count result : $current_result \n";
}

if($success_count > 1) {
    $status_internet_ip = 1;
    print "Internet Connection appears OK\n";
}

#check a named host on the Internet
my $internet_hostname = "google.com";
$success_count = 0;
for(my $count = 0; $count < 4; $count++) {
    my $current_result = $p->ping($internet_hostname, 3);
    if($current_result == 1) {
        $success_count = $success_count + 1;
    }
    print "Ping $internet_hostname $count result : $current_result \n";
}

my $status_internet_hostname = 0;
if($success_count > 1) {
    $status_internet_hostname = 1;
    print "Internet Hostname appears OK\n";
}

$p->close();


# save these results to MySQL ...

my $db_name = "bwlimits";
my $db_user = "bwlimit";
open CFGFILE, "</etc/bwlimit.pw" or die $!;
my @cfglines = <CFGFILE>;
my $db_pass = $cfglines[1];
chomp($db_pass);
my $dsn = "dbi:mysql:$db_name:localhost:3306";

our $DBIconnect = DBI->connect($dsn, $db_user, $db_pass) or die "Could not connect to DB";
print "Connected to DB\n";
my $update_query_sql = "UPDATE connection_status SET gateway_status = '$status_gateway', "
    . " internet_ip = '$status_internet_ip', internet_hostname = '$status_internet_hostname',"
    . " externalip = '$external_ip', gatewayip = '$gateway_ip', last_updated = now()";
my $update_query_handle = $DBIconnect->prepare($update_query_sql);
$update_query_handle->execute();
