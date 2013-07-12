#!/usr/bin/perl -wT

#
# BWLimit Squid External ACL
#
# This perl script is a Squid External ACL as defined at
# http://devel.squid-cache.org/external_acl/config.html
#
# There are two ways this can work:
#  1. If you were using a new version of squid (>2.5) just feed it the IP,
#     it will give user=<username> and you can use an acl ext_user ...
#
#  2. If you are using squid 2.5 you will need to use an ACL that mentions
#      the username you want to check the IP against
#       e.g. acl useracl_isuser external bwlimit_byip username
#
#


use strict;
use warnings;


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


#TODO: fix this to lookup from database option - timeout in seconds
my $ip_activity_timeout = 1200;

$|=1;
my $username = "";

while (<>) {
    #find out what IP this came from...
    my @parts = split;
    my $srcip = $parts[0];
    my $minimum_acceptable_last_usage_time = time() - $ip_activity_timeout;
    
    my $sql_lookup = "SELECT username from user_details WHERE active_ip_addr = '$srcip' "
                        . " AND (last_ip_activity > $minimum_acceptable_last_usage_time OR login_method = 'static')";
    my $query_handle = $DBIconnect->prepare($sql_lookup);
    $query_handle->execute();
    $query_handle->bind_columns(undef, \$username);

    #now see if we have usernames to check against
    my $num_parts = @parts;
    if($num_parts > 1) {
        #we need to check and see if this is in the list we were given...
        my $result = "ERR\n";
        if($query_handle->fetch()) {
            my @user_in_list = grep(/\b$username\b/, @parts);
            if(@user_in_list) {
                $result = "OK user=$username\n";
            }
        }
        print $result;
    }else {
        if($query_handle->fetch()) {
            print "OK user=$username\n";
        }else {
            print "OK\n";
        }
    }

}

