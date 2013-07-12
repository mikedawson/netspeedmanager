#!/usr/bin/php

<?php
require_once "/usr/lib/bwlimit/bwlimit-config.php";
require_once "/usr/lib/bwlimit/bwlimit-functions.php";


connectdb();


$table_status_sql = "show table status from bwlimits";
$table_status_result = mysql_query($table_status_sql);
$table_status_arr = null;

while(($table_status_arr = mysql_fetch_assoc($table_status_result)) != null) {
	$commentval = $table_status_arr['Comment'];
	$isnot_crashed = strpos($commentval, "crashed");
	if(!($isnot_crashed === FALSE)) {
		echo $table_status_arr['Name'] . " is crashed!\n";
		mysql_query("Repair table $table_status_arr[Name]");
	}
}


?>
