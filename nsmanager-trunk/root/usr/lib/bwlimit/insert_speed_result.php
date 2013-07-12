#!/usr/bin/php

<?php
require_once "/etc/nsm.conf.php";

mysql_connect($BWLIMIT_DBHOST, $BWLIMIT_DBUSER, $BWLIMIT_DBPASS);
mysql_select_db($BWLIMIT_DBNAME);


$vel_rx = $argv[1];
$vel_tx = $argv[2];
$utime = $argv[3];

$sql = "insert into speed_check set rx=$vel_rx,tx=$vel_tx,stamp_inserted='$utime'";


mysql_query($sql);



?>
