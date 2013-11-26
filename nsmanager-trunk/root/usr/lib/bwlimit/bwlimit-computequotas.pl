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

our @user_list = $adb->users;

for my $current_user (@user_list) {
    print "Checking for user ", $current_user->key, "\n";
    my @current_user_group_list = $adb->user_group_list($current_user->key);

    my $user_httpsblock = '-';

    #daily, weekly, monthly
    my @max_quota_so_far = (
            int($current_user->prop('BWLimitDaily') || 0) ,
            int($current_user->prop('BWLimitWeekly') || 0) ,
            int($current_user->prop('BWLimitMonthly')|| 0) ,
	    int($current_user->prop('BWLimitRateDown') || 0),
	    int($current_user->prop('BWLimitCeilDown') || 0),
   	    int($current_user->prop('BWLimitRateUp') || 0),
            int($current_user->prop('BWLimitCeilUp') || 0)

);

    my $bwlimit_groupname = $current_user->prop("BWLimitCountGroup") || "";
    
    if($bwlimit_groupname ne "" && $bwlimit_groupname ne "unsorted") {
        my $current_group_check = $adb->get("$bwlimit_groupname");
        my @this_groups_limits =
            ($current_group_check->prop('BWLimitDaily') || 0,
            $current_group_check->prop('BWLimitWeekly') || 0,
            $current_group_check->prop('BWLimitMonthly') || 0,
	    $current_group_check->prop('BWLimitRateDown') || 0,
	    $current_group_check->prop('BWLimitCeilDown') || 0,
	    $current_group_check->prop('BWLimitRateUp') || 0,
	    $current_group_check->prop('BWLimitCeilUp') || 0,
	    
	);

        for(my $i = 0; $i < 7; $i++) {
            if(int($this_groups_limits[$i]) > $max_quota_so_far[$i]) {
                $max_quota_so_far[$i] = int($this_groups_limits[$i]);
            }
        }

	my $group_blockdirecthttps = $current_group_check->prop('BWLimit_blockdirecthttps') || '-';
	if($group_blockdirecthttps eq "y") {
		$user_httpsblock = "y";
	}
    }

    for(my $i = 0; $i < 3; $i++) {
        #Convert bytes into MB tokens
        my $quota_norm = new Math::BigInt $max_quota_so_far[$i];
        $quota_norm->bmul(1024 * 1024);
        $max_quota_so_far[$i] = $quota_norm;
        print "   this quota = $quota_norm \n";
    }

    my $user_httpsblock_property = $current_user->prop('BWLimit_blockdirecthttps') || '-';

    if($user_httpsblock_property eq "y") {
	$user_httpsblock = "y";
    }
   
    if($user_httpsblock_property eq "n"){
	$user_httpsblock = "n";
    }

    my $blockdirecthttps_sqlval = 0;
    if($user_httpsblock eq "y") {
	$blockdirecthttps_sqlval = 1;
        print "\t user block https";
    }

    print "User ", $current_user->key, " Has Monthly Quota ", $max_quota_so_far[2], "\n";
    my $current_username = $current_user->key;
    my $mac_addr1 = $current_user->prop('BWLimitMACAddress') || "";
    my $mac_addr2 = $current_user->prop('BWLimitMACAddress2') || "";
    my $ip_addr = $current_user->prop('staticip') || "";

    #look and see what should be the parent htb class
    my $parent_htb = get_htbparent_for_username($current_username);

    #check the authentication source
    my $authsource = $current_user->prop("BWLimitAuthSource") || "local";

    #see if this exists or not
    my $user_exists_sql = "SELECT username from user_details where username = '$current_username'";
    my $user_exists_query_handle = $DBIconnect->prepare($user_exists_sql);
    $user_exists_query_handle->execute();
    if($user_exists_query_handle->rows > 0) {
        my $update_sql = "UPDATE user_details SET daily_limit = $max_quota_so_far[0],"
            . " weekly_limit = $max_quota_so_far[1], monthly_limit = $max_quota_so_far[2],"
	    . " ratedown = $max_quota_so_far[3], ceildown = $max_quota_so_far[4], "
	    . " rateup = $max_quota_so_far[5], ceilup = $max_quota_so_far[6], "
            . " mac_addr1 = '$mac_addr1', mac_addr2 = '$mac_addr2',ip_addr = '$ip_addr', blockdirecthttps = '$blockdirecthttps_sqlval', "
            . " htbparentclass = $parent_htb, authsource =  '$authsource' " 
            . " WHERE username = '$current_username'";
        my $update_handle = $DBIconnect->prepare($update_sql);
        $update_handle->execute();
        print "Updated $current_username \n";
    }else {
        #here check and see if we should add the permission for creating guest accounts
        my $query_sql = "REPLACE INTO user_details (username, daily_limit, weekly_limit, monthly_limit, ratedown, ceildown, rateup, ceilup, within_quota, mac_addr1, mac_addr2,ip_addr,htbparentclass) "
                            . " VALUES ('$current_username', $max_quota_so_far[0], $max_quota_so_far[1], "
                            . " $max_quota_so_far[2] , $max_quota_so_far[3], $max_quota_so_far[4], $max_quota_so_far[5], $max_quota_so_far[6], 1, '$mac_addr1', '$mac_addr2','$ip_addr', '$parent_htb')";
        my $query_handle = $DBIconnect->prepare($query_sql);
        $query_handle->execute();
        print "Inserted $current_username";
    }

}
