#!/usr/bin/php

<?php
/* 
 * This command will set the bandwidth limit timeranges
 *
 */

require_once "bwlimit-functions.php";
require_once "bwlimit-config.php";

connectdb();

/*
if($argc != 4) {
    echo "Usage: bwlimit_set_timerange.php <name> <timing in squid acl format> <rate>";
    exit(1);
}
 * 
 */

$timerange_name = $argv[1];
$timerange_range = $argv[2];
$timerange_rate = $argv[3];

$sql = "REPLACE INTO time_ranges (timerange_time_name, timerange_timerange, timerange_rate) "
    . " VALUES ('$timerange_name', '$timerange_range', '$timerange_rate')";
mysql_query($sql);

$debugfile = fopen("/tmp/someit", "a");
fwrite($debugfile, "tried SQL $sql\n");

fwrite($debugfile, "called with $timerange_name $timerange_range $timerange_rate\n");
fclose($debugfile);

?>
