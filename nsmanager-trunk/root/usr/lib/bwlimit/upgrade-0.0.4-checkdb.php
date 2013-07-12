#!/usr/bin/php
<?php
/*
 * Delete a couple annoying columns if they are there
 */

require("/usr/lib/bwlimit/bwlimit-config.php");
require("/usr/lib/bwlimit/bwlimit-functions.php");

connectdb();

$sql2 = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE table_name = 'user_details' AND COLUMN_NAME = 'htbparentclass'";
$sql2_result = mysql_query($sql2);
if(mysql_num_rows($sql2_result) == 0) {
        $sql_addstamp = "ALTER TABLE user_details add column htbparentclass int(11) default '0'";
        mysql_query($sql_addstamp);
}

