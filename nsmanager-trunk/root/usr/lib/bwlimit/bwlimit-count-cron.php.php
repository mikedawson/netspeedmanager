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

//Used to count bandwidth usage in this run, associated array using the username
$userbwtotals = array();

//array that counts the raw total in bytes (not token count)
$userbwtotals_bytes = array();

//count how much bandwidth the user saved through the cache...
$userbwtotals_saved = array();
$userbwtotals_saved_reqs = array();

$userbwtotals_scheduledxfers = array();

//used to check the last time that an ip address was seen
$useriplastseen = array();

//used to track the oldest entry that we have seen in the pmacct data so we know
// what we can safely delete
$pmacct_oldest_time = 0;

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
 * This will check the last seen ip time on the username and update the cache
 * variable useriplastseen accordingly.
 * 
 * Time should be unix time (seconds since epoch)
 * 
 * @global <type> $useriplastseen
 * @param <type> $username
 * @param <type> $time 
 */
function update_user_last_seen_cache($username, $time) {
    global $useriplastseen;
    global $ip_activity_timeout;

    if(!$useriplastseen[$username]) {
        $useriplastseen[$username] = intval($time);
        echo "Set useriplastseen for $username = $time\n";
    }

    if($useriplastseen[$username]) {
        $timeintval = intval($time);
        if($timeintval > $useriplastseen[$username]) {
            $useriplastseen[$username] = $timeintval;
        }
    }
}


/**
 * This function will run SQL that will clear an inactive IP address from the list
 * and deactivate them from iptables etc.
 *
 * $running_mode must be set to "ByIP" for this to do anything
 *
 */
function clear_inactive_ips() {
    $date_log = date(DATE_RFC850);

    fwrite($inactivity_fd, $date_log . ": " . "Checking for inactive IPs\n");

    global $BWLIMIT_OPTIONS, $running_mode, $ip_activity_timeout, $inactivity_fd, $dhcp_timeout;

    if($running_mode && $running_mode == "ByIP") {
        $find_inactive_ips_sql = "SELECT * FROM user_details WHERE "
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

        //the bwlimit_user_ip_control function should now update this per user itself


        //$clear_old_ips_sql = "Update user_details SET active_ip_addr = '' WHERE "
        //    . "(unix_timestamp() - last_ip_activity) > $ip_activity_timeout "
        //    . " AND active_ip_addr != '' AND active_ip_addr IS NOT NULL";
        //mysql_query($clear_old_ips_sql);
    }
}

/**
 * Given a result set with a username, time and bytes row this will count the
 * amount of bandwidth used by the user for any other protocol...
 *
 * Also does the update to the last timestamp seen
 *
 * @param <type> $resultset
 */
function process_pmacct_result_set($resultset) {
    global $userbwtotals;
    global $userbwtotals_bytes;
    global $pmacct_oldest_time;
    global $cron_debug_fd;
    global $DEBUG_CRON;
    
    $row = null;
    while(($row = mysql_fetch_assoc($resultset)) != null) {
        $username = $row['username'];
        $time = intval($row['utime']);
        if($time > $pmacct_oldest_time) {
            $pmacct_oldest_time = $time;
        }
        
        $bytecount = $row['bytes'];
        $rate = getrate($time);
        $bw_to_count = $rate * floatval($bytecount);

        if(empty($userbwtotals[$username])) {
            $userbwtotals[$username] = 0;
        }
        if(empty($userbwtotals_bytes[$username])) {
            $userbwtotals_bytes[$username] = 0;
        }

        $userbwtotals[$username] += $bw_to_count;
        $userbwtotals_bytes[$username] += floatval($bytecount);
        
        if($bytecount > 0) {
            echo "\tFound $row[bytes] for user $username\n";
            update_user_last_seen_cache($username, $time);
        }
        echo "User: $username : \t\t $bw_to_count tokens | $bytecount bytes (Rate = $rate)\n";
    }   
}



/**
 * Count the bandwidth usage from the pmacct table.
 * 
 * Update the IP last time seen information for the username if we are running 
 * in ByIP mode
 * 
 * Then delete the data that we have gone through
 */
function process_pmacct_data() {
    global $pmacct_oldest_time;
    global $running_mode;
    global $local_ip;
    global $local_netmask;
    global $userbwtotals;
    global $userbwtotals_scheduledxfers;
    global $userbwtotals_bytes;

    $sql_setup_type_check = "SELECT setup_type FROM process_log";
    $setup_type_result = mysql_query($sql_setup_type_check);
    $setup_arr_assoc = mysql_fetch_assoc($setup_type_result);

    $setup_type = $setup_arr_assoc['setup_type'];
    if($setup_type == "ByIP") {
        echo "doing PMACCT queries...\n\n";
        $running_mode = "ByIP";

        /*
         * This query runs against the acct v1 table generated by pmacct
         *
         * It counts the sum of the bytes, gets the time so that we can see when
         * the ip was last actie and in the where clause we do a netmask comparison
         * so that we do not count local bandwidth (e.g. access to the shared drive)
         *
         * See also the inet_aton function here:
         *  http://dev.mysql.com/doc/refman/5.0/en/miscellaneous-functions.html
         */
	/*
        $sql_outgoing = "select acct.bytes as bytes, user_details.username AS username, "
            ."unix_timestamp(acct.stamp_inserted) as utime FROM acct, user_details "
            . "WHERE acct.ip_dst = user_details.active_ip_addr ";
	*/

	$sql_outgoing = "select acct.bytes as bytes, acct.ip_dst as ip_dst, unix_timestamp(acct.stamp_inserted) as utime, 
user_details.username as username FROM acct LEFT JOIN user_details ON acct.ip_dst = user_details.active_ip_addr WHERE (acct.ip_dst is 
not null AND acct.ip_dst != '')";

        echo "Outgoing count SQL: $sql_outgoing";
        $outgoing_result = mysql_query($sql_outgoing);

	/*
        $sql_incoming = "select acct.bytes as bytes, user_details.username AS username, "
            ."unix_timestamp(acct.stamp_inserted) as utime FROM acct, user_details "
            . "WHERE acct.ip_src = user_details.active_ip_addr ";
	*/
	$sql_incoming = "select acct.bytes as bytes, acct.ip_src as ip_src, unix_timestamp(acct.stamp_inserted) as utime, 
user_details.username as username FROM acct LEFT JOIN user_details ON acct.ip_src = user_details.active_ip_addr WHERE (acct.ip_src is 
not null AND acct.ip_src != '')";
	
        echo "Incoming count SQL: $sql_incoming";
        
        $incoming_result_set = mysql_query($sql_incoming);

        process_pmacct_result_set($outgoing_result);
        process_pmacct_result_set($incoming_result_set);

        echo "\n==============byte totals in pmacct count function=============\n";
        var_dump($userbwtotals_bytes);

        //TODO: Count bandwidth usage vs time per user

        echo "=== CALCULATE BANDWIDTH USAGE IN KBPS ===";
        echo "\n\n";
        $get_user_kbps =  "select acct.bytes as bytes, sum(acct.bytes) as totalbytes,count(acct.bytes) * 30 as seconds, user_details.username AS username,unix_timestamp(acct.stamp_inserted) as utime FROM acct, user_details WHERE acct.ip_dst = user_details.active_ip_addr OR acct.ip_src = user_details.active_ip_addr group by username";
        $set_user_kbps = "UPDATE user_details SET current_kbps=''";



        //TODO: Check if there are only scheduled downloads going on here - if so still need to deal with it

        mysql_query($set_user_kbps);
        $get_user_kbps_result = mysql_query($get_user_kbps);
        $get_user_kbps_arr = null;
        while(($get_user_kbps_arr = mysql_fetch_assoc($get_user_kbps_result))){
            $temp_kbps = (($get_user_kbps_arr[totalbytes]/$get_user_kbps_arr[seconds])*8)/1024;
            $username = $get_user_kbps_arr[username];
            $update_kbps = "UPDATE user_details SET current_kbps=".$temp_kbps." WHERE username = '".$get_user_kbps_arr[username]."'";
            echo "$update_kbps";
            mysql_query($update_kbps);
            echo $get_user_kbps_arr[username]."Updated OK";
            echo "\n";

        }
        echo "userbwtotals scheduled for update function\n";
        var_dump($userbwtotals_scheduledxfers);
        foreach($userbwtotals_scheduledxfers as $username => $scheduled_xfer) {
            
            //TODO: change this to use timestamps etc.
            echo "Adding $scheduled_kbps to $username for scheduled transfers \n";
            $scheduled_kbps = intval($scheduled_xfer);
            $scheduled_query = "Update user_details SET current_kbps = current_kbps + $scheduled_kbps WHERE username = '$username'";
            echo "run $scheduled_query \n";
            mysql_query($scheduled_query);
        }

        //Clear the old times
        $clearout_query = "DELETE FROM acct WHERE unix_timestamp(stamp_inserted) <= $pmacct_oldest_time";
        echo "Running $clearout_query \n";
        mysql_query($clearout_query);
    }

    var_dump($userbwtotals);
}


/*
 * This function looks at the line, parses it and determines which user
 * used how much bandwidth in this entry.
 *
 * It counts according to the bandwidth 'rate' which is defined for this time
 *
 */
function process_line($line) {
    global $userbwtotals;
    global $userbwtotals_bytes;
    global $userbwtotals_saved;
    global $userbwtotals_saved_reqs;
    global $running_mode;
    global $BWLIMIT_UPDATEFILTER;
    global $BWLIMIT_CONNECTIONSPEED_EXISTING;

    if(empty($userbwtotals[$user])) {
        $userbwtotals[$user] = 0;
    }


    //$BWLIMIT_UPDATEFILTER = "/(archive.ubuntu.com|security.ubuntu.com|au.windowsupdate.com)/";
    
    //echo "Update Filter = $BWLIMIT_UPDATEFILTER";

    //determine the user and size here
    $line_parts = preg_split("/\s/", $line, -1,  PREG_SPLIT_NO_EMPTY);

    //According to the normal squid log format - see squid.conf access_log for details
    //TODO : Implement IP based processing here...
    $user = $line_parts[7];
    $size = $line_parts[4];
    $status = $line_parts[3];
    $time_elapsed = intval($line_parts[1]);
    $logged_url = $line_parts[6];
    //echo "status = $status ";

    //if we saved
    if(preg_match('/HIT/', $status)) {
        $userbwtotals_saved_reqs[$user] += 1;
        $userbwtotals_saved[$user] += intval($size);
    }else {
        //see if this was an update saved in apt-cache or the like... - calc in kbps
        $xferrate = (($size * 8)/1024) / ($time_elapsed / 1000);
        if($xferrate > $BWLIMIT_CONNECTIONSPEED_EXISTING) {
            //then it was a hit...
            $userbwtotals_saved_reqs[$user] += 1;
            $userbwtotals_saved[$user] += intval($size);
        }
    }


    //Because the first entry in the log is the timestamp in secondssinceepoch.millis
    //so just look up to the first . to gets seconds since epoch
    $utime_parts = explode(".", $line, 2);
    $utime = intval($utime_parts[0]);
    if($running_mode && $running_mode == "ByIP") {
        update_user_last_seen_cache($user, $utime);
    }

    //uncount updates
    $bw_to_count = getrate($utime) * floatval($size);
    

    if(preg_match($BWLIMIT_UPDATEFILTER, $logged_url)) {
        echo " Uncount $bw_to_count for $user (update)\n";

        $userbwtotals[$user] -= $bw_to_count;
    }

    //think this is actually being done in pmacct section
    

    //NOTE: This should not be counted here - we are counting it using pmacctd...

    //determine the timerange that we are in
    //$userbwtotals[$user] += $bw_to_count;


    
    //$userbwtotals_bytes[$user] += floatval($size);

    
}


/*
 * This function will skip to the next log line that it has not yet processed
 * and then start calling process_line
 *
 * It will then update the usage database
 */
function process_file($filename) {
    global $userbwtotals;
    global $running_mode;
    global $DEBUG_CRON;

    if($DEBUG_CRON == 1) {
        echo "Opening $filename Squid log\n";
    }

    $fd = fopen($filename, "r");
    $line = "";
    $linecount = 0;

    //double check the kind of setup that we have
    $sql = "SELECT setup_type";



    //find out the oldest timestamp we have looked at so far
    $sql = "SELECT setup_type, last_processed_timestamp, size_last_counted, previous_first_timestamp FROM process_log";
    $sql_result = mysql_query($sql);
    $sql_result_arr = mysql_fetch_assoc($sql_result);
    $last_timestamp_proc = $sql_result_arr['last_processed_timestamp'];
    $last_timestamp_proc_float = floatval($last_timestamp_proc);
    $running_mode = $sql_result_arr['setup_type'];

    $process_zone = false;

    $last_processed_timestamp = "";

    $first_timestamp_in_file = "";

    echo "Going through lines... ";
    while(!feof($fd)) {
        $line = fgets($fd);
        
        $parts = split(" ", $line, 2);
        $timestamp = $parts[0];

        if($linecount == 0) {
            //this is the first line - see if this is the file that we last looked at
            // if it is then seek ahead to save a lot of time...
            $previous_first_timestamp = $sql_result_arr['previous_first_timestamp'];
            $first_timestamp_in_file = $timestamp;
            if($first_timestamp_in_file == $previous_first_timestamp) {
                //this is the one we saw...
                echo "First Timestamp in file = $first_timestamp_in_file\n, line = $line";
                $bytes_to_skip = intval($sql_result_arr['size_last_counted']);
                echo "Recognize this log... seeking... $bytes_to_skip bytes";
                
                fseek($fd, $bytes_to_skip);
            }
        }

        


        //check and see if we have reached somewhere to start processing
        if(($process_zone == false) && (floatval($timestamp) > $last_timestamp_proc_float)) {
            $process_zone = true;
        }

        if($process_zone && $timestamp != "") {
            process_line($line);
            $last_processed_timestamp = $timestamp;
        }

        $linecount++;
        if($linecount % 100 == 0) {
            echo $linecount . ", ";
        }
    }



    

    /* This is now obsolete - happens after counting pmacct stuff...
    echo "================================================\n";
    echo "User Totals From counting Squid Traffic: \n";
    echo "================================================\n";
    foreach($userbwtotals as $username => $usertotal) {
        echo "User: $username \t\t: $usertotal\n";

        //TODO: Note - do we want to count here, ahead of processing pmacct data?
        count_bandwidth($username, $usertotal);
    }
    echo "================================================\n";
    */

    //update the time that I last looked at the logs
    if($last_processed_timestamp != "") {
        $filesize_processed = filesize($filename);
        $last_ts_sql = "UPDATE `process_log` set last_processed_timestamp = '$last_processed_timestamp', "
            . " previous_first_timestamp = '$first_timestamp_in_file', size_last_counted = '$filesize_processed' "
            . " WHERE servicename = 'squid'";
        mysql_query($last_ts_sql);
        echo "Updated timestamp\n";
    }

}

function check_pid_running($pid) {
    $cmd = "ps $pid";
    exec($cmd, $output, $result);
    if(count($output) >= 2) {
        return true;
    }else {
        return false;
    }
}

/**
 * Opens up a wget log according to the given filename and then returns an array
 *
 * completed - true / false
 */
function check_wget_log($logfilename) {
    $charsperline = 82;
    $linestoconsider = 10;
    $fd = fopen($logfilename, "r");
    $logfilesize = filesize($logfilename);
    $lines = array();

    //because of the chance of large logs try to skip if possible some lines...
    if($logfilesize > ($charsperline * $linestoconsider)) {
        $bytestoskip = $logfilesize - ($charsperline * $linestoconsider);
        fseek($fd, $bytestoskip);
    }

    $lineread = null;
    $linecount = 0;
    while(($lineread = fgets($fd))) {
        $lines[$linecount] = $lineread;
        $linecount++;
    }

    //look for the magic word 'saved'
    $dlcomplete = false;
    for($i = sizeof($lines) - 1; $i >= 0; $i--) {
        $currentmatches = array();
        preg_match('/.* (saved) .*/', $lines[$i], &$currentmatches);
        if($currentmatches[1] && $currentmatches[1] == 'saved') {
            //found the magic word saved - return this info
            $dlcomplete = true;
            break;
        }
    }

    $returnval = array();
    $returnval['completed'] = $dlcomplete;

    return $returnval;
}

/**
 * This function will go through all the scheduled transfers and check their status
 * if the process died for any reason, what to start stop etc.
 *
 * There are two different kinds of transfers - http_download and ftp_upload
 * they are started and counted differently but paused in the same manner
 * by killing the process
 * 
 */
function checkscheduledxfers() {
    global $userbwtotals;
    global $userbwtotals_scheduledxfers;

    $request_xfer_sql = "SELECT * FROM xfer_requests WHERE status != 'complete'";
    $request_xfer_result = mysql_query($request_xfer_sql);
    $row = null;

    //find out what time it is now to see what needs stopped and started
    $time_now = time();
    while(($row = mysql_fetch_assoc($request_xfer_result)) != null) {
        $current_xfer_status = $row['status'];
        $user = $row['user'];

        echo "checking $row[requestid] status $current_xfer_status\n";
        if($current_xfer_status == 'waiting') {
            $current_xfer_start_time = intval($row['start_time']);
            //check if this should be started
            echo "checking start time DL: $current_xfer_start_time Now: $time_now\n";
            if($current_xfer_start_time < $time_now) {
                echo "Time to start download $row[requestid]\n";
                if($row['type'] == "http_download") {
                    start_download($row['requestid']);
                }else if($row['type'] == "ftp_upload") {
                    start_upload($row['requestid']);
                }
                echo "started download/upload\n";
            }
        }else if($current_xfer_status == 'inprogress') {
            //check that the process is alive, count bandwidth usage
            //check if it should be stopped
            if($row['type'] == "http_download") {
                //see how much bandwidth we have counted, how much the file has increased...
                echo "counting bandwidth for $row[requestid] \n";
                $countedbytes = $row['countedbytes'];
                $currentsize = filesize($row['output_file']);
                $bytes_to_charge = max(array($currentsize - $countedbytes, 0));
                if($bytes_to_charge > 0) {
                    $tokens_to_charge = getrate(time()) * $bytes_to_charge;
                    $userbwtotals[$user] += $tokens_to_charge;
                    echo "Charging user $user $tokens_to_charge for scheduled download $row[requestid]\n";
                    if(empty($userbwtotals_scheduledxfers[$user])) {
                        $userbwtotals_scheduledxfers[$user] = 0;
                    }
                    //time used = time now - time last updated
                    $timeused = time() - intval($row['last_counted']);
                    $scheduled_kbps = (((intval($bytes_to_charge)*8)/1024) / $timeused);

                    $userbwtotals_scheduledxfers[$user] += $scheduled_kbps;
                }

                $kb_downloaded = intval($currentsize / 1024);
                $utime_now = time();
                $countedbyte_update_sql = "UPDATE xfer_requests SET countedbytes = $currentsize "
                    . " , comment = 'In Progress Downloaded $kb_downloaded KB', last_counted = $utime_now "
                    . " WHERE requestid = $row[requestid]";
                mysql_query($countedbyte_update_sql);

                //check and see if this download has completed
                $wget_log_filename = $row['output_file'] . "-download-log.txt";
                $wget_log_check_info = check_wget_log($wget_log_filename);

                if($wget_log_check_info['completed'] == true) {
                    echo "   Download Complete!";

                    //OK let's deliver it and mark it appropriately
                    $filebasename = basename($row['output_file']);
                    $delivercmd = "/usr/lib/bwlimit/netspeedmanager_deliverdownload "
                        . $row['user'] . " \"$filebasename\"";
                    exec($delivercmd);

                    //mark it as done
                    $completeupdatesql = "UPDATE xfer_requests SET status = 'complete' "
                        . " WHERE requestid = $row[requestid]";
                    mysql_query($completeupdatesql);
                }else {
                    //make sure that it's still being worked on
                    $pidrunning = check_pid_running($row['pid']);
                    if($pidrunning == false) {
                        echo "Found dead download - restarting...";
                        start_download($row[requestid]);
                    }
                }
            }

        }else if($current_xfer_status == "req_pause") {
            //user would like to pause this
            $pid = $row['pid'];
            echo "Should pause $pid \n";

            if(intval($pid) > 10) {
                exec("/bin/kill $pid");
                $pause_update_sql = "UPDATE xfer_requests SET status = 'pause' "
                    . ", comment = 'Currently Paused' WHERE requestid = $row[requestid] ";
                mysql_query($pause_update_sql);
                echo "Paused download $row[requestid]\n";
            }
        }
    }
    echo "===Dumping scheduled xfer transfer counts===\n";
    var_dump($userbwtotals_scheduledxfers);

    echo "Done with download function\n";
}

echo "hmmm...\n\n";

//Load fundamentals of the system setup
init_load_sysvals();

echo "processing squid log file\n\n";
//Do the main squid log analysis
//process_file($BWLIMIT_SQUIDACCESSLOG_FILE);

//see how downloads / uploads are going...
//do this before going through pmacct data so that we can see what users have used
//before updating the bandwidth usage tables
checkscheduledxfers();

//Go through pmacct data
echo "Processing pmacct data\n";
process_pmacct_data();



//need a function to count that bandwidth recorded in the vars...


//Check the quotas and block whoever exceeded it.   Also update when this ip was last active
echo "\n===Calling checkquotas()===\n";
checkquotas();

echo "\n=== Recording Bandwidth Usage===\n";
insert_all_bandwidth_usage();

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
    fflush($cron_debug_fd);
    fclose($cron_debug_fd);
}

fflush($inactivity_fd);
fclose($inactivity_fd);
?>
