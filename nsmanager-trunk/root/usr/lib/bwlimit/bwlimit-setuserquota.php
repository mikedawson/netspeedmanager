#!/usr/bin/php5
<?php
/*
 * This system will set a quota for any given user
 *
 * bwlimit-setuserquota username <dailylimitinbytes> <weeklylimitinbytes> <monthlylimitinbytes>
 */
if($argc != 5) {
    echo "usage: bwlimit-setuserquota username <dailylimitinbytes> <weeklylimitinbytes> <monthlylimitinbytes> \n";
    exit(1);
}

require_once "bwlimit-config.php";
require_once "bwlimit-functions.php";

connectdb();

$daily_limit = intval($argv[2]) * (1024 * 1024);
$weekly_limit = intval($argv[3]) * (1024 * 1024);
$monthly_limit = intval($argv[4]) * (1024 * 1024);

$sql = "Update user_details set daily_limit = $daily_limit, weekly_limit = $weekly_limit, monthly_limit = $monthly_limit "
        . " WHERE username = '$argv[1]'";
mysql_query($sql);

if(mysql_affected_rows() == 0) {
    //not there yet we need to insert...
    $sql = "INSERT INTO user_details (username, daily_limit, weekly_limit, monthly_limit, within_quota) "
        . "VALUES ('$argv[1]', $daily_limit, $weekly_limit, $monthly_limit, 1)";
    mysql_query($sql);
}



?>
