<?php

/*
 * This page generates an XML response for use with AJAX to show users
 * their download progress
 *
 */
require_once "bwlimit_user_functions.php";
require_once "../bwlimit-functions.php";
require_once "bwlimit_user_config.php";

connectdb();

check_login();

header("Content-Type: application/json");


//the user 
$username = $_SESSION['user'];

$user_xferinfo_sql = "SELECT * FROM xfer_requests WHERE user = '$username'";
$user_xferinfo_result = mysql_query($user_xferinfo_sql);
$user_xferinfo_arr = null;

$allresults_arr = array();
while(($user_xferinfo_arr = mysql_fetch_assoc($user_xferinfo_result)) != null) {
    $status = $user_xferinfo_arr['status'];
    $file_exists = file_exists($user_xferinfo_arr['output_file']);
    if($file_exists == true) {
        //check the exact downloaded bytes so far
        $user_xferinfo_arr['file_exists'] = 1;
        $user_xferinfo_arr['filesize'] = filesize($user_xferinfo_arr['output_file']);
    }else {
        $user_xferinfo_arr['file_exists'] = 0;
    }
    
    $user_xferinfo_arr['start_time_formatted'] = date("H:i", $user_xferinfo_arr['start_time']);
    $allresults_arr[sizeof($allresults_arr)] = $user_xferinfo_arr;
}

echo json_encode($allresults_arr);

?>