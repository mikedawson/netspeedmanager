#!/usr/bin/php
<?php
/* 
 * Delete a couple annoying columns if they are there
 */

require("/usr/lib/bwlimit/bwlimit-config.php");
require("/usr/lib/bwlimit/bwlimit-functions.php");

connectdb();

$sql = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE table_name = 'data_usage' AND (COLUMN_NAME = 'ip_src' OR COLUMN_NAME = 'ip_dst')";

$sql_result = mysql_query($sql);
$sql_assoc = null;

while(($sql_assoc = mysql_fetch_assoc($sql_result)) != null) {
    $sql_drop = "ALTER TABLE data_usage DROP COLUMN $sql_assoc[COLUMN_NAME]";
    mysql_query($sql_drop);
}

$sql2 = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE table_name = 'macipcombos' AND COLUMN_NAME = 'leasetimestamp'";
$sql2_result = mysql_query($sql2);
if(mysql_num_rows($sql2_result) == 0) {
	$sql_addstamp = "ALTER TABLE macipcombos add column leasetimestamp int";
	mysql_query($sql_addstamp);
}


?>



