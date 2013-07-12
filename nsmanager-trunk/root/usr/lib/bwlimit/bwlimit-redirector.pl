#!/usr/bin/perl -wT

#
# BWLimit Squid Redirector (PERL)
#
#


use strict;
use warnings;


use DBI;
use DBD::mysql;
use URI::Escape;

use esmith::bwlimit::bwlimit_utils;
use esmith::FormMagick;
use esmith::AccountsDB;
use esmith::ConfigDB;
use Scalar::Util qw(looks_like_number);

#Required to handle large quotas...
use Math::BigInt;

#MySQL stuff

our $db_name = "bwlimits";
our $db_user = "bwlimit";
open CFGFILE, "</etc/bwlimit.pw" or die $!;
my @cfglines = <CFGFILE>;
our $db_pass = $cfglines[1];
chomp($db_pass);

my $dsn = "dbi:mysql:$db_name:localhost:3306";

our $DBIconnect = DBI->connect($dsn, $db_user, $db_pass) or die "Could not connect to DB";

$DBIconnect->{mysql_auto_reconnect} = 1;

#check and see the setup type now
my $setup_type_query_sql = "SELECT setup_type, exceedpolicy FROM process_log";
my $setup_type_query_handle = $DBIconnect->prepare($setup_type_query_sql);
our $setup_type_result = "";
our $exceedpolicy = "";


#naughty - should be in a config place...
our $ip_activity_timeout = 86400;

$setup_type_query_handle->execute();
$setup_type_query_handle->bind_columns(undef, \$setup_type_result, \$exceedpolicy);
$setup_type_query_handle->fetch();


my $local_hostname = `hostname --fqdn`;
chomp($local_hostname);


#TODO: Fix me this is bad
my $local_ip_addr = "10.10.1.2";


sub user_within_quota {
    my $username = shift;
    if($username) {
	#if only deprioritizing - leave it... let tc take care of it
        if($exceedpolicy eq "deprio") {
	        return 1;
	}
        my $lookup_sql = "SELECT within_quota FROM user_details WHERE username = '$username'";
        my $query_handle = $DBIconnect->prepare($lookup_sql) or die "SQL Error on redirector";
        $query_handle->execute() or die "SQL Error on redirector";
        my $within_quota_result = "";
        $query_handle->bind_columns(undef, \$within_quota_result);
        if($query_handle->fetch()) {
            if($within_quota_result eq "1") {
                return 1;
            }else {
                return 0;
            }
        }
    }
    # if we are here this user is not in the db....
    return -1;
}


#
# Lookup the username by the IP that activity should have been coming from
#
# Return the username if this is an authenticated active IP - 0 otherwise
#
sub find_username_by_ip {
    my $user_ipaddr = shift;

    if(!defined($DBIconnect)) {
	return -1;
    }

    my $min_acceptable_activity_time = time() - $ip_activity_timeout;
    my $find_username_sql = "SELECT username from user_details WHERE active_ip_addr "
        . " = '$user_ipaddr' AND ((last_ip_activity > $min_acceptable_activity_time) OR (login_method = 'static'))";
    my $username_query_handle  = $DBIconnect->prepare($find_username_sql);
    $username_query_handle->execute() || return -1;
    my $username_result = "";
    $username_query_handle->bind_columns(undef, \$username_result);
    if($username_query_handle->fetch()) {
        return $username_result;
    }

    #means we didn't find it in the db...
    return 0;
}


$|=1;
my $username = "";
my $over_quota_redir = "https://" . $local_hostname . "/bwlimit/overquota.php";
my $login_page = "https://" . $local_hostname . "/bwlimit/bwlimit_userlogin.php";


while (<>) {
    #find out the user
    my $username = "";
    my @parts = split;
    my $client_ip_section = $parts[1];
    my @client_ip_parts = split(/\//, $client_ip_section);
    my $client_ip_addr = $client_ip_parts[0];
    my $url = $parts[0];

    #if it's the server itself (e.g. cache primer) then just let it go...
    if($client_ip_addr eq $local_ip_addr) {
        print $url . "\n";
        next;
    }

    #TODO: Take this from the configuration variable
    if($url =~ m/(archive.ubuntu.com|security.ubuntu.com|au.windowsupdate.com)/) {
        print $url . "\n";
        next;
    }

    if($setup_type_result eq "ByIP") {
        #we need to find out what user this actually is....  if not redirect to login page    
        $username = &find_username_by_ip($client_ip_addr);
    }else {
        $username= $parts[2];
    }

    if(looks_like_number($username)) {
        if($username == -1) {
    	    #means SQL got disconnected - try again
            $DBIconnect = DBI->connect($dsn, $db_user, $db_pass);
	    if(defined($DBIconnect)) {
                $username = &find_username_by_ip($client_ip_addr);
	    }
        }
    }	
    
    my $url_escaped = uri_escape($url);
    if($url =~ m/($local_hostname)/ || $url =~ m/($over_quota_redir)/) {
        print $url . "\n";
    } elsif($username eq 0) {
        print "302:$login_page?redir=$url_escaped\n";
    } elsif($username eq -1) {
	print "302:$login_page?redir=$url_escaped&error=1\n";
    }else {
        my $user_within_quota_result = &user_within_quota($username);
        if($user_within_quota_result eq 0) {
            print "302:$over_quota_redir\n";
        }else {
            print $url . "\n";
        }
    }
}
