#!/usr/bin/perl

use esmith::ConfigDB;

# username to check out

my $username = $ARGV[0];

# Time duration to go  back in seconds
my $duration = $ARGV[1];

$FH = "filehandle";
$FilePath = "/var/log/squid/access.log";

open(FH, $FilePath);


$OFH = "outfilehandle";
my $outfilename = "/usr/lib/bwlimit/testuser.log";


my $line = "";

my $timenow = time();
my $mintime = $timenow - $duration;

# find out which downloads don't count as updates etc.

my $db = esmith::ConfigDB->open();
my $update_filter_rec = $db->get("BWLimitUpdateFilter");
#my $update_filter_expr = $update_filter_rec->prop("type");
my $update_filter_expr = `db configuration get BWLimitUpdateFilter`;
$update_filter_expr=~ s/\s+$//;



foreach $line (<FH>) {
    my $timestamp = $line;
    $timestamp =~ m/(\d+)\.(.*)/;
    $timestamp = $1;
    if($timestamp > $mintime) {
        #print $timestamp;
        #see if this is the user we are looking for
        my @parts = split(/\s+/, $line);
        
        if($parts[7] eq $username) {
            #check that this is not a 'free' update
            my $url = $parts[6];
            if($url =~ m/$update_filter_expr/g) {
                #do nothing - this is an update...
            }else {
                print $line;
            }
        }
    }
}
