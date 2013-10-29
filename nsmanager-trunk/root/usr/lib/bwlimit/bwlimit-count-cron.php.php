#!/usr/bin/php
<?php
/* 
 * This small cron job will try and count the bandwidth that has been used
 * by the different users by looking through the logs
 * 
 * It will note the last timestamp that it saw - skip through the file until
 * it finds that, and then process the entries
 *
 * Then process all the lines to determine how much bandwidth each user actually
 * used
 *
 * Then when done counting do the SQL once and only once
 */

require("/usr/lib/bwlimit/bwlimit-config.php");
require("/usr/lib/bwlimit/bwlimit-functions.php");

connectdb();


$userbwtotals_scheduledxfers = array();

$last_timestamp = 0;

$BWLIMIT_CONNECTIONSPEED_EXISTING=512;
$inactivity_fd = fopen("/usr/lib/bwlimit/inactivity-cut.log", "a");

if($DEBUG_CRON == 1) {
    echo "Starting with Debug Mode enabled";
    $debug_fd = fopen($cron_debug_log_file, "a");
}else {
    echo "Starting without debug mode enabled";
}

/**
 * This function will run SQL that will clear an inactive IP address from the list
 * and deactivate them from iptables etc.
 *
 * $running_mode must be set to "ByIP" for this to do anything
 *
 */
function clear_inactive_ips() {
    global $BWLIMIT_OPTIONS, $running_mode, $ip_activity_timeout, $inactivity_fd, $dhcp_timeout;

    $date_log = date(DATE_RFC850);    
    fwrite($inactivity_fd, $date_log . ": " . "Checking for inactive IPs\n");


    if($running_mode && $running_mode == "ByIP") {
        $find_inactive_ips_sql = "SELECT * FROM user_sessions WHERE "
            . "((unix_timestamp() - last_ip_activity) > $ip_activity_timeout AND  "
            . " active_ip_addr != '' AND active_ip_addr is not null AND login_method = 'web')";

        echo "FIND INACTIVE USERS:\n running $find_inactive_ips_sql \n";
        $find_inactive_ips_result = mysql_query($find_inactive_ips_sql);
        $find_inactive_ip_row = null;
        while(($find_inactive_ip_row = mysql_fetch_assoc($find_inactive_ips_result))!= null) {
            //this now inactive so deactivate it...
            $thisoldip = $find_inactive_ip_row['active_ip_addr'];
            $username = $find_inactive_ip_row['username'];
            $inactive_msg =  " Deactivating $thisoldip for user $username due to inactivity\n";
            echo $inactive_msg;
            $inactive_logme = date(DATE_RFC850) . " : " . $inactive_msg;

            fwrite($inactivity_fd, $inactive_logme);
            bwlimit_user_ip_control($username, $thisoldip, false, true);
        }
    }
}

/*
 * This will use the newly structured data_usage table and the bytes value
 * 
 */
function sum_user_bandwidth($username) {
    $time_last_counted_sql = "SELECT last_counted_utime FROM user_details WHERE username = '$username'";
    $time_last_counted_result = mysql_query($time_last_counted_sql);
    $time_last_counted_arr = mysql_fetch_assoc($time_last_counted_result);
    if($time_last_counted_arr) {
        $time_last_counted = $time_last_counted_arr['last_counted_utime'];
        $usage_sql = "SELECT SUM(bytes) AS sum, MAX(stamp_inserted) AS last_time FROM data_usage WHERE username = '$username' "
                . " AND stamp_inserted > $time_last_counted ";
        echo $usage_sql;
        $usage_result = mysql_query($usage_sql);
        $usage_arr = mysql_fetch_assoc($usage_result);
        if($usage_arr) {
            $bytes_count = $usage_arr['sum'];
            $last_time = $usage_arr['last_time'];
            $rate = getrate($time_last_counted);
            
            echo "\tRate = $rate\n";
            
            $bw_to_count = $rate * floatval($bytes_count);
            echo "user mike transferred $bytes_count since last count count $bw_to_count \n";
            $days_since_epoch = day_since_epoch(time());

            $update_stmt = "UPDATE `usage_logs` SET `usage` = `usage` + $bw_to_count ,"
                . " `usage_bytes` = `usage_bytes` + $bytes_count  "
                . " WHERE `userlogid` = '$username:$days_since_epoch' ";

            echo " run update: $update_stmt\n\n";
            mysql_query($update_stmt);

            //check if this is a new user; if yes then create their record
            if(mysql_affected_rows() < 1) {
                $insert_stmt =
                    "INSERT INTO `usage_logs` (`userlogid`, `user`, `dayindex`,  "
                    . "`usage`, `usage_bytes`) VALUES ( "
                    . "'$username:$days_since_epoch', '$username', '$days_since_epoch', "
                    . "$bw_to_count, $bytes_count  )";
                mysql_query($insert_stmt);
                echo " ran $insert_stmt\n\n";
            }
            
            //update the last seen time
            //this needs to be done per ip for this user as one device might be inactive whilst another is active
            $user_session_sql = "select username, active_ip_addr, ipbytecount FROM user_sessions WHERE username = '$username'";
            $user_session_result = mysql_query($user_session_sql);
            $user_session_arr = null;
            $dirlist = array("up", "down");
            while(($user_session_arr = mysql_fetch_assoc($user_session_result))) {
                $ipbytecount = 0;
                //this needs escaped before it is fed into grep so we get only exact whole matches
                $ip_with_esc_codes = str_replace(".", "\\.", $user_session_arr['active_ip_addr']);
                foreach($dirlist as $dir) {
                    $byte_cmd = "/sbin/iptables -t mangle -L htb-gen.$dir -n -v -x | "
                            . "grep htb-gen.$dir-$username | grep '$ip_with_esc_codes ' | awk ' { print $1 }'";
                    
                    $byte_result = `$byte_cmd`;
                    //echo "\t byte result = $byte_result\n";
                    if($byte_result != null && $byte_result != "") {
                        //echo "\t\t its numerics\n";
                        $ipbytecount += $byte_result;
                    }
                }
                
                //echo "Byte count $username / $user_session_arr[active_ip_addr] = $ipbytecount \n";
                
                if(intval($ipbytecount) > intval($user_session_arr['ipbytecount'])) {
                    echo "\tACTIVITY from $username on $user_session_arr[active_ip_addr] found\n";
                    $update_time_sql = "Update user_sessions set ipbytecount = '$ipbytecount', "
                            . " last_ip_activity = '$last_time' "
                            . " WHERE username = '$username' AND active_ip_addr = '"
                            . $user_session_arr['active_ip_addr'] . "'";
                    mysql_query($update_time_sql);
                }
                
            }
        }
    }
}

function sum_all_users_bandwidth() {
    $userlist_sql = "SELECT DISTINCT username FROM user_sessions";
    $userlist_result = mysql_query($userlist_sql);
    $userlist_arr = null;
    while(($userlist_arr = mysql_fetch_assoc($userlist_result))) {
        sum_user_bandwidth($userlist_arr['username']);
    }
}

//Load fundamentals of the system setup
init_load_sysvals();

//Sum up bandwidth
sum_all_users_bandwidth();


//Check the quotas and block whoever exceeded it.   Also update when this ip was last active
echo "\n===Calling checkquotas()===\n";
checkquotas();


//Run a query to clear out the ip addresses that are now inactive
clear_inactive_ips();

//check the status of tables and do auto repair if needed on database
exec("/usr/lib/bwlimit/check_tables.php");

//check and see if we need to stop the cache primer
$cache_prime_check_sql = "SELECT pid, time_started FROM bwlimit_cache_primer";
$cache_prime_result = mysql_query($cache_prime_check_sql);
if(mysql_num_rows($cache_prime_result) > 0) {
	$cache_prime_arr = mysql_fetch_assoc($cache_prime_result);
	$cache_prime_pid = intval($cache_prime_arr['pid']);
	//time_started
	if($cache_prime_pid != 0) {
		//calculate the finish time
		$cacheprime_duration = intval(`/sbin/e-smith/db configuration getprop BWLimit CachePrimerRunTime`);
		$cacheprime_time_started = intval($cache_prime_arr['time_started']);
		if(time() > ($cacheprime_time_started + $cacheprime_duration)) {
			//stop it...
			echo "Terminating cache primer - time is over\n";
			exec("/bin/kill $cache_prime_pid");

			//time in seconds to attempt to kill the process before getting mean
			$cache_prime_timeout = 10;
			
			for($killcount = 0; $killcount < $cache_prime_timeout; $killcount++) {
				sleep(1);
				if(is_dir("/proc/$cache_prime_pid") === FALSE) {
					echo "\tPrime Process is gone after $killcount seconds\n";
					//process is gone
					break;
				}

				if($killcount == (cache_prime_timeout - 1)) {
					echo "Process did not die yet - getting nasty - kill -9\n";
					exec("/bin/kill -9 $cache_prime_pid");
				}
			}

			$update_primer_sql = "update bwlimit_cache_primer SET pid = 0";	

			//make the report
			exec("/usr/lib/bwlimit/bwlimit-cache-primer-doreport.sh $cacheprime_time_started");

			mysql_query($update_primer_sql);			
		}
		
	}
}

//check and make sure graph stuff is OK
graphcheck();

if(file_exists("/usr/lib/bwlimit/reset-required")) {
	echo "signalling event";
	exec("/sbin/e-smith/signal-event bwlimit-full-update");
	unlink("/usr/lib/bwlimit/reset-required");
}

check_autoreset_users();

if($DEBUG_CRON) { 
    if($cron_debug != null) {
        fflush($cron_debug_fd);
        fclose($cron_debug_fd);
    }
}


fflush($inactivity_fd);
fclose($inactivity_fd);
?>