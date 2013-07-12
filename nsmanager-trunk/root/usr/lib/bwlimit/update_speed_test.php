#!/usr/bin/php

<?php
require_once "/etc/nsm.conf.php";

mysql_connect($BWLIMIT_DBHOST, $BWLIMIT_DBUSER, $BWLIMIT_DBPASS);
mysql_select_db($BWLIMIT_DBNAME);


$status = $argv[1];

$sql = "";
if("$status" == "0") {
	//new one starting
	mysql_query("delete from speedcheck_control");
	$timenow = time();
	$sql = "insert into speedcheck_control (timestarted,status,inprogress) values($timenow,0,1)";
}else if("$status" == "1") {
	$sql = "update speedcheck_control set status = 1";
}else if("$status" == "2") {
	$sql = "update speedcheck_control set status = 2, inprogress = 0";
}

mysql_query($sql);



?>
