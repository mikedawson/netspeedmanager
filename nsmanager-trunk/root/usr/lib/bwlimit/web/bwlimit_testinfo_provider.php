<?php
header("Content-Type: application/xml");

require_once "../bwlimit-functions.php";
connectdb();
check_login();

$username = $_SESSION['user'];

require_once "bwlimit_user_functions.php";


/*
 * This file provides information to test clients so they can determine
 * if the server has recorde client action correctly.
 * 
 */

$action = $_REQUEST['action'];



?>
