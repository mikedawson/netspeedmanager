<?php
header("Content-Type: application/xml");
header("Cache-Control: no-cache");



require_once "../bwlimit-functions.php";
require_once "bwlimit_user_functions.php";

connectdb();
check_login();

echo  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";


$username = $_SESSION['user'];




/*
 * This file provides information to test clients so they can determine
 * if the server has recorde client action correctly.
 * 
 */

$action = $_REQUEST['action'];

function get_last_ipactivity_time($user, $addr) {
    $last_mod_time_sql = "SELECT last_ip_activity FROM user_sessions WHERE username = '$user' AND "
            . " active_ip_addr = '$addr'";
    $last_mod_time_result = mysql_query($last_mod_time_sql);
    $last_mod_time_arr = mysql_fetch_assoc($last_mod_time_result);
    $last_mod_time = $last_mod_time_arr['last_ip_activity'];
    return $last_mod_time;
}


if($action == "sumbwcalcentries") {
    /**
     * Sum the entries that are coming from calcbytes
     */
    $start_utime = mysql_real_escape_string($_REQUEST['start_utime']);
    $end_utime = mysql_real_escape_string($_REQUEST['end_utime']);
    $sum_query = "SELECT SUM(bytes) AS totalbytes FROM data_usage WHERE username = '$username' AND "
            . " stamp_inserted >= $start_utime AND stamp_inserted <= $end_utime ";
    //echo $sum_query;
    $sum_result = mysql_query($sum_query);
    $sum = 0;
    if(mysql_num_rows($sum_result)) {
        $sum_result_assoc = mysql_fetch_assoc($sum_result);
        $sum = $sum_result_assoc['totalbytes'];
    }
    echo "<bwcalcsums>";
    echo "<sum><bytetotal>$sum</bytetotal></sum>";
    echo "</bwcalcsums>";
}

$ip_addr = $_SERVER['REMOTE_ADDR'];

if($action == "getiplastactivitytime") {
    $last_mod_time = get_last_ipactivity_time($username, $ip_addr);
    echo "<iplastactivitytime><result><time>$last_mod_time</time></result></iplastactivitytime>";
}

if($action == "updatelastactivitytime") {
    echo "<iplastactivitytime><serverblah>";
    sum_user_bandwidth($username);
    $last_mod_time = get_last_ipactivity_time($username, $ip_addr);
    echo "</serverblah><result><time>$last_mod_time</time></result></iplastactivitytime>";
}


?>
