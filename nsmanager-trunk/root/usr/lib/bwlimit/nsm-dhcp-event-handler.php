#!/usr/bin/php
<?php
/* 
 * This will handle DHCP events when a lease is issued or expires
 */

require("/usr/lib/bwlimit/bwlimit-config.php");
require("/usr/lib/bwlimit/bwlimit-functions.php");



connectdb();

$evtname = $argv[1];
$ipaddr = $argv[2];
$macaddr = $argv[3];


if($evtname == "commit") {
    //Step 1 look up the ip address - if we have a different mac already active - cut it off
    //this should not really happen because we should always have an expiry event beforehand...
    $existing_query1_sql = "SELECT * from macipcombos WHERE ipaddr = '$ipaddr'";
    $existing_query1_result = mysql_query($existing_query1_sql);
    if(mysql_num_rows($existing_query1_result) > 0) {
        //check if the mac address is a mis match
        echo "There is a recorded lease here\n";
        $existing_query1_assoc = mysql_fetch_assoc($existing_query1_result);
        if($existing_query1_assoc['macaddr'] != $macaddr) {
            $usernamelookup_sql = "SELECT username FROM user_sessions WHERE active_ip_addr = '$ipaddr'";
	        echo "looking for user: $usernamelookup_sql \n";
            $usernamelookup_result = mysql_query($usernamelookup_sql);
            
            if(mysql_num_rows($usernamelookup_result) > 0) {
                //The lease has been given to someone else - we need to make sure that this ip does not get given
                //access on the last person's account - check if there is an active user on the account
            
                $usernamelookup_assoc = mysql_fetch_assoc($usernamelookup_result);
                $oldusername = $usernamelookup_assoc['username'];
                
                //deactivate the old username, on that ip, and force the run
                echo "Deactivating IP $ipaddr for username $oldusername - it's a new mac address\n";
                bwlimit_user_ip_control($oldusername, $ipaddr, false, true);
            }
        }
        
        //now delete it - it shouldnt be around anymore... if it is then the dhcp messed up big time
        $delete_oldmac_sql = "DELETE FROM macipcombos WHERE ipaddr = '$ipaddr'";
        echo "Deleting with $delete_oldmac_sql \n";
        mysql_query($delete_oldmac_sql);
        
    }
    
    //now record the lease
    $lease_record_sql = "REPLACE INTO macipcombos (macaddr, ipaddr, leasetimestamp) VALUES "
        . "('$macaddr', '$ipaddr', unix_timestamp())";
    mysql_query($lease_record_sql);
    
    //check and see if this is a mac address that wants automatic activation
    $usermac_sql = "SELECT username FROM usersavedmacs WHERE macaddr = '$macaddr'";
    echo "Running $usermac_sql to look for mac addressses\n";
    $usermac_result = mysql_query($usermac_sql);
    if(mysql_num_rows($usermac_result) > 0) {
        //this should get activated
        $usermac_assoc = mysql_fetch_assoc($usermac_result);
        $username = $usermac_assoc['username'];
        
        //run - activate=true, force = false , method = dhcp
        echo "activating for $username\n";
        bwlimit_user_ip_control($username, $ipaddr, true, false, "dhcp");
    }
    
}else if($evtname == "expiry") {
    //delete this from the lease table
    $delete_lease_sql = "DELETE FROM macipcombos WHERE ipaddr = '$ipaddr'";
    mysql_query($delete_lease_sql);

    $findusername_sql = "select username FROM user_sessions WHERE active_ip_addr = '$ipaddr'";
    $findusername_result = mysql_query($findusername_sql);
    if(mysql_num_rows($findusername_result) > 0) {
        $findusername_assoc = mysql_fetch_assoc($findusername_result);
        $oldusername = $findusername_assoc['username'];
        echo "Deactivating IP $ipaddr for username $oldusername - lease expired\n";
        bwlimit_user_ip_control($oldusername, $ipaddr, false, true);
    }
}


?>


