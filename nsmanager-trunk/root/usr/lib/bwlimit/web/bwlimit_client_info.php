<?php
/* 
 * This page generates XML info that can be read by a client application
 * to find out about the user's status
 */
header("Content-Type: application/xml");
require_once "../bwlimit-functions.php";
connectdb();

require_once "bwlimit_user_functions.php";


check_login();

$css_colors = array("green", "yellow", "red");

//check what the thresholds are

$username = $_SESSION['user'];

$bwinfo = null;
if($username) {
    $bwinfo = get_bwinfo($username);
    $xml = "<?xml version='1.0' encoding='UTF-8'?>\n";
    $xml .= "<nsminfo>\n";
    $timeperiod_names = array('daily', 'weekly','monthly');
    foreach($timeperiod_names as $timeperiod_name) {
        $xml .= "<timeperiod name='$timeperiod_name'>\n";
        $xml .= "<status timeperiod='$timeperiod_name' id='status_$timeperiod_name'>" . $bwinfo[$timeperiod_name][status] . "</status>\n";
        $xml .= "<savedbytes timeperiod='$timeperiod_name' id='savedbytes_$timeperiod_name'>". $bwinfo[$timeperiod_name][saved_bytes] . "</savedbytes>";
        $xml .= "<savedtime timeperiod='$timeperiod_name' id='savedtime_$timeperiod_name'>" . $bwinfo[$timeperiod_name][saved_time] . "</savedtime>";
        $xml .= "</timeperiod>\n";
    }
    $xml .= "</nsminfo>";
    echo $xml;

}else {
    $xml = "<?xml version='1.0' encoding='UTF-8'?>\n";
    $xml .= "<nsminfo><loggedout/></nsminfo>";
}


?>