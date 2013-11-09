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