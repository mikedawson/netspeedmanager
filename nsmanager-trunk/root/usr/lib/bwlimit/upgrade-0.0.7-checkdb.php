#!/usr/bin/php
<?php
/*
 * Add columns for authentication source and account status tracking
 */

require("/usr/lib/bwlimit/bwlimit-config.php");
require("/usr/lib/bwlimit/bwlimit-functions.php");

connectdb();

$sql2 = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE table_name = 'user_details' AND COLUMN_NAME = 'authsource'";
$sql2_result = mysql_query($sql2);
if(mysql_num_rows($sql2_result) == 0) {
        $sql_addsrc = "ALTER TABLE user_details add column authsource varchar(32) default 'local'";
        mysql_query($sql_addsrc);
        $sql_addsrc2 = "ALTER TABLE user_details add column acctready int default 1";
        mysql_query($sql_addsrc2);
}
?>