#!/usr/bin/php
<?php
/* 
 * This CLI utility is designed to be called by a script / daemon etc. to
 * run when a given mac address is connected.
 */

require_once "/usr/lib/bwlimit/bwlimit-config.php";
require_once "/usr/lib/bwlimit/bwlimit-functions.php";

connectdb();




if($argc != 3) {
    echo "Usage: bwlimit_activate_by_macaddr.php macaddress ipaddr \n";
    exit(1);
}
$mac_addr = $argv[1];
$ip_addr = $argv[2];

//now record the mac and ip combo
$record_sql = "REPLACE INTO macipcombos (macaddr, ipaddr) VALUES ('$mac_addr', '$ip_addr')";
mysql_query($record_sql);


$activate_username = null;

$sql_query = "SELECT username from user_details WHERE mac_addr1 = '$mac_addr' OR mac_addr2 = '$mac_addr'";
$sql_result = mysql_query($sql_query);
if(mysql_num_rows($sql_result) > 0) {
    $sql_arr = mysql_fetch_assoc($sql_result);
    $activate_username = $sql_arr['username'];
    echo "Activating $username on $ip_addr based on value from main config\n";
}else {
    $find_user_mac_sql = "SELECT username from usersavedmacs WHERE macaddr = '$mac_addr'";
    $find_user_mac_result = mysql_query($find_user_mac_sql);
    if(mysql_num_rows($find_user_mac_result) > 0) {
        $find_user_mac_arr = mysql_fetch_assoc($find_user_mac_result);
        $activate_username = $find_user_mac_arr['username'];
    }
    echo "Activating username on $ip_addr based on value saved by user";
}
if($activate_username != null) {
    bwlimit_user_ip_control($activate_username, $ip_addr, true, false, "dhcp");
    echo "Activated $ip_addr for $activate_username";
}else {
    echo "Sorry - no user account found associated with $mac_addr \n";
}


?>