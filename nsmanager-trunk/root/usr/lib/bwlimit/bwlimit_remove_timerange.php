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
if($argc != 2) {
    echo "Usage: bwlimit_set_timerange.php <name> <timing in squid acl format> <rate>";
    exit(1);
}
 * 
 */

$timerange_name = $argv[1];


$sql = "DELETE FROM time_ranges WHERE timerange_time_name = '$timerange_name'";

mysql_query($sql);


?>
