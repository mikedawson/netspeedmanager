<?php



require_once "/usr/lib/bwlimit/bwlimit-config.php";

/**
 * The last time rate that was checked - unix time
 */
$last_time_rate_checked = -1;

/**
 * Array of the time ranges that are in operation
 */
$timeranges = null;

/*
 * (Cached) the 'rate' at which the bandwidth will be charged for the last
 * time range
 * 
 */
$last_time_rate = -1;

/*
 * The Local IP of the system so that we can count bandwidth external
 */
$local_ip = "";

/*
 * The Local Netmask of the system so that we can count bandwidth external
 */
$local_netmask = "";

//This is either "ProxyAuth" or "ByIP"
$running_mode = "";


//Days of the week according to Squid
$days_squidnames = array(
        0 => 'S',
        1 => 'M',
        2 => 'T',
        3 => 'W',
        4 => 'H',
        5 => 'F',
        6 => 'A'
    );


$BWLIMIT_ALREADY_CONNECTED = 0;


function connectdb() {
    global $BWLIMIT_DBHOST;
    global $BWLIMIT_DBUSER;
    global $BWLIMIT_DBPASS;
    global $BWLIMIT_DBNAME;
    global $BWLIMIT_ALREADY_CONNECTED;

    if($BWLIMIT_ALREADY_CONNECTED == 0 || $BWLIMIT_ALREADY_CONNECTED == False) {
        mysql_connect($BWLIMIT_DBHOST, $BWLIMIT_DBUSER, $BWLIMIT_DBPASS);
        $BWLIMIT_ALREADY_CONNECTED = mysql_select_db($BWLIMIT_DBNAME);
    }

}


/**
 * This function will load the system default values for IP address,
 * netmask, setup type etc.
 */
function init_load_sysvals() {
    global $local_ip;
    global $local_netmask;
    global $running_mode;

    $sql = "SELECT setup_type, local_ip, local_netmask from process_log";
    $net_ip_result = mysql_query($sql);
    $net_ip_assoc = mysql_fetch_assoc($net_ip_result);
    $local_ip = $net_ip_assoc['local_ip'];
    $local_netmask = $net_ip_assoc['local_netmask'];
    $running_mode = $net_ip_assoc['setup_type'];
}

function load_time_ranges() {
    global $timeranges;

    $sql = "SELECT * FROM time_ranges";
    $result = mysql_query($sql);
    $row = null;

    $timeranges = array();

    while(($row = mysql_fetch_assoc($result)) != null) {
        $timerange_time_name = $row['timerange_time_name'];
        $timerange_timerange = $row['timerange_timerange'];
        $timerange_rate = $row['timerange_rate'];

        $timeranges[$timerange_time_name] = array();
        $timeranges[$timerange_time_name]['range'] = $timerange_timerange;
        $timeranges[$timerange_time_name]['rate'] = $timerange_rate;
    }
}


/**
 * This function will check and see if this username can create a guest
 * account or not
 *
 * return true if they can, false otherwise.
 *
 * @param <type> $username
 */
function bwlimit_can_create_guest_account($username) {

    $sql_check_user_stmt = "SELECT can_create_guest_acct FROM user_details WHERE "
        . " username = '$username'";

    $check_user_result = mysql_query($sql_check_user_stmt);
    $check_user_arr = mysql_fetch_assoc($check_user_result);

    if($check_user_arr['can_create_guest_acct'] == '1') {
        return true;
    }else {
        return false;
    }
}


/**
 * This function should determine the 'rate' at which the bandwidth will be
 * added.
 *
 * This is the highest rate that applies to the given time.
 *
 * @param <type> $time - unix time (seconds since epoch)
 *
 * You must connect to the database before call this function, and you must load
 * the time ranges...
 */
function getrate($time) {
    global $timeranges;
    global $last_time_rate_checked;
    global $last_time_rate;

    if($timeranges == null) {
        load_time_ranges();
    }

    //see if we have already checked this time (cached)
    if($time == $last_time_rate_checked) {
        return $last_time_rate;
    }

    //different time, so go through all the ranges that apply

    $maxrate = 1;
    foreach($timeranges as $timerange_name => $timerange_values) {
        if(range_applies_to_time($time, $timerange_values['range'])) {
            $timerate = floatval($timerange_values['rate']);
            if($timerate > $maxrate) {
                $maxrate = $timerate;
            }
        }
    }

    $last_time_rate_checked = $time;
    $last_time_rate = $maxrate;

    return intval($maxrate) ;
}


/**
 * Starts or resumes an FTP upload by calling the NSM ftp uploader
 *
 */
function start_upload($xferjobid) {
    $proc_descriptor = array(
            0 => array("pipe", "r"), //stdin is a pipe that the child will read from
            1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
            2 => array("pipe", "w") //stderr a pipe that will be written to
        );

    $process = proc_open("/usr/lib/bwlimit/scheduledxfer/fork_upload.sh $xferjobid",
            $proc_descriptor, $pipes);

    echo "Starting upload $xferjobid\n";
}


/**
 * Starts or resumes a download by calling wget with the -b option that will
 *
 */
function start_download($xferjobid) {
    $lookup_sql = "SELECT * FROM xfer_requests WHERE requestid = $xferjobid";
    echo "lookup SQL = $lookup_sql";
    $lookup_result = mysql_query($lookup_sql);
    $lookup_arr = mysql_fetch_assoc($lookup_result);

    $errormsg = "";
    //we are gonna use squid pam auth instead...
    $proc_descriptor = array(
        0 => array("pipe", "r"), //stdin is a pipe that the child will read from
        1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
        2 => array("pipe", "w") //stderr a pipe that will be written to
    );
    $cwd = "/tmp";
    $env = array();
    $url = $lookup_arr['url'];
    $outputfilename = $lookup_arr['output_file'];

    //make sure that we have a directory for it to go into
    $destdirname = dirname($outputfilename);
    echo "destdirname = $destdirname";
    exec ("/bin/mkdir -p '$destdirname'");
    exec ("/bin/chown www:www $destdirname");



    /*
     * What we will do is open a wget background process, read the output
     * from that and then use that to find out the pid that has been launched
     *
     */
    $process = proc_open("/usr/bin/wget --continue --background --tries=0 "
        . " --output-document=\"$outputfilename\" "
        . " --output-file=\"$outputfilename-download-log.txt\" "
        ." \"$url\"  ", $proc_descriptor, $pipes);
    if(is_resource($process)) {
        // $pipes now looks like this:
        // 0 => writeable handle connected to child stdin
        // 1 => readable handle connected to child stdout
        //fputs($pipes[0], "$username $pass\n");
        //fclose($pipes[0]);

        $line = "";
        $firstline = "";
        $count = 0;
        while(($line = fgets($pipes[1]))) {
            if($count == 0) {
                $firstline = $line;
            }
            $count++;
            echo $line;
        }

        $groups = array();
        preg_match('/pid (\d+)/', $firstline, &$groups);
        $pid = $groups[1];

        //now update the status of this in the database
        $utime_now = time();
        $download_update_stmt = "UPDATE xfer_requests SET `pid` = $pid "
            . ", status = 'inprogress', last_counted = $utime_now, comment = 'Starting...' "
            . " WHERE requestid = $xferjobid";
        mysql_query($download_update_stmt);

        proc_close($process);
    }
}
/**
 * Function to check if a given timerange applies to a given time
 *
 * returns true if it does, false otherwise
 *
 * Timerange should be in the squid format [Day Initials] [StartTime-FinishTime]
 *
 * Finish Time must be greater than Start Time (e.g. cannot wrap around midnight)
 *
 * @param <type> $time
 * @param <type> $rangestr
 */
function range_applies_to_time($time, $rangestr) {
    global $days_squidnames;
    //split this up into the day section and

    $day_section = "";
    $time_section = "";

    if(is_numeric(substr($rangestr, 0, 1))) {
        //this is a time only str
        $time_section = $rangestr;
    }else {
        $entries = preg_split("/ /", $rangestr);
        if(count($entries) == 1) {
            //this is day only
            $day_section = $rangestr;
        }else {
            $day_section = $entries[0];
            $time_section = $entries[1];
        }
    }

    $day_matches = true;

    $time_matches = true;

    $date_info = getdate($time);
    if($day_section != "") {
        
        $day_of_week = $date_info['wday'];

        if(strstr($day_section, $days_squidnames[$day_of_week]) == false) {
            $day_matches = false;
        }
    }

    if($time_section != "") {
        $time_parts = explode("-", $time_section);
        $start_time_str = explode(":", $time_parts[0]);

        //check me against manual
        $hr_now = $date_info['hours'];
        $min_now = $date_info['minutes'];


        $time_matches = false;
        if( ($hr_now > intval($start_time_str[0])
                || ($hr_now == intval($start_time_str[0]) && $min_now > intval($min_now)))) {
            // we are after the start time, lets check finish time
            $end_time_str = explode(":", $time_parts[1]);

            if($hr_now < intval($end_time_str[0]) ||
            ($hr_now == intval($end_time_str[0]) && $min_now < intval($end_time_str))) {
                $time_matches = true;
            }
        }

    }
    

    if($time_matches && $day_matches) {
        return true;
    }else {
        return false;
    }
    
}



/**
 * Utility function as we will be counting the days since the epoch as our
 * means of tracking
 *
 * @param <type> $seconds_since_epoch
 * @return <type>
 */
function day_since_epoch($seconds_since_epoch) {
    return floor($seconds_since_epoch / 86400);
}

/**
 *
 * used to find the amount to add to usage totals from an array...
 */
function amount_to_add_from_key($username, $arr) {
    if($arr[$username]) {
        return intval($arr[$username]);
    }
    
    return 0;
}

function insert_all_bandwidth_usage() {
    global $userbwtotals;
    global $userbwtotals_bytes;

    echo "\n==============byte totals=============\n";
    var_dump($userbwtotals_bytes);
    

    foreach($userbwtotals as $username => $usagetotal) {
        insert_bandwidth_usage($username);
    }
}

/**
 * Inserts the bandwidth usage of a user to the database
 *
 * @global <type> $userbwtotals
 * @global <type> $userbwtotals_bytes
 * @global <type> $userbwtotals_saved
 * @global <type> $userbwtotals_saved_reqs
 * @param <type> $user
 */
function insert_bandwidth_usage($user) {
    global $userbwtotals;

    //array that counts the raw total in bytes (not token count)
    global $userbwtotals_bytes;

    //count how much bandwidth the user saved through the cache...
    global $userbwtotals_saved;
    global $userbwtotals_saved_reqs;

    
    //TODO: add latency detection
    $latency_time_ms = 800;

    $requests_saved = amount_to_add_from_key("user", $userbwtotals_saved_reqs);
    
    //time saved = time saved per KB (seconds) x byte count saved x 0.001 (convert to KB) x 1000 (convert to ms)
    $dltimesaved = 0.04 * amount_to_add_from_key($user, $userbwtotals_saved) * 0.001 * 1000;

    $time_saved = $dltimesaved + ($requests_saved * $latency_time_ms);

    $updateamounts = array(
        "usage" => amount_to_add_from_key($user, $userbwtotals),
        "usage_bytes" => amount_to_add_from_key($user, $userbwtotals_bytes),
        "saved_bytes" => amount_to_add_from_key($user, $userbwtotals_saved),
        "saved_time" => $time_saved
    );

    $days_since_epoch = day_since_epoch(time());

    $update_stmt = "UPDATE `usage_logs` SET `usage` = `usage` + $updateamounts[usage] ,"
        . " `usage_bytes` = `usage_bytes` + $updateamounts[usage_bytes] , "
        . " `saved_bytes` = `saved_bytes` + $updateamounts[saved_bytes] , "
        . " saved_time = `saved_time` + $updateamounts[saved_time] "
        . " WHERE `userlogid` = '$user:$days_since_epoch' ";

    //echo " run update: $update_stmt\n\n";
    mysql_query($update_stmt);

    //check if this is a new user; if yes then create their record
    if(mysql_affected_rows() < 1) {
        $insert_stmt =
            "INSERT INTO `usage_logs` (`userlogid`, `user`, `dayindex`,  "
            . "`usage`, `usage_bytes`, `saved_bytes`, `saved_time`) VALUES ( "
            . "'$user:$days_since_epoch', '$user', '$days_since_epoch', "
            . "$updateamounts[usage], $updateamounts[usage_bytes], $updateamounts[saved_bytes], "
            . "$updateamounts[saved_time] )";
        mysql_query($insert_stmt);
        //echo " ran $insert_stmt\n\n";
    }

}

/**
 *
 * This function will record an amount of bandwidth as being used by this user
 *
 * @param <type> $user
 * @param <type> $size
 */
function count_bandwidth($user, $size) {




    if($size == 0) {
        return;
    }

    //check days since epoch
    $day_since_epoch = day_since_epoch(time());
    echo "day since epoch: $day_since_epoch\n";


    $update_sql = "UPDATE `usage_logs` SET `usage` = `usage` + $size WHERE `userlogid` = '$user:$day_since_epoch'";
    echo " run update: $update_sql";
    mysql_query($update_sql);

    //check if this is a new user; if yes then create their record
    if(mysql_affected_rows() < 1) {
        //we need to add this user to the db now
        $insert_sql = "INSERT INTO usage_logs (`userlogid`, `user`, `dayindex`, `usage`) VALUES "
            . " ('$user:$day_since_epoch', '$user', $day_since_epoch, $size)";
        mysql_query($insert_sql);
        echo "Ran insert for $user | $insert_sql";
    }
}


/**
 * Get the sum of this user's bandwidth usage from starting between last_day
 * being the most recent day going back numdays
 *
 * Should be in days_since_epoch
 *
 * @param <type> $numdays
 * @param <type> $starting_day
 */
function sum_bandwidth_usage($numdays, $last_day, $username, $colName = "usage") {
    $earliest_day_to_consider = $last_day - $numdays;
    $query_sql = "SELECT SUM(`$colName`) as totalusage FROM `usage_logs` WHERE `user` = '$username' "
        . " AND dayindex > $earliest_day_to_consider AND dayindex <=  $last_day";
    $query_result = mysql_query($query_sql);

    //perhaps nothing done yet...
    if(mysql_num_rows($query_result) == 0) {
        return 0;
    }

    $result_assoc = mysql_fetch_assoc($query_result);
    return $result_assoc['totalusage'];
}

/**
 * This function will check and see if any of the users are over their quota
 *
 * If they are over any quota (daily, weekly, or monthly) then they will be
 * disabled
 *
 */
function checkquotas() {
    global $BWLIMIT_DEBUGOUTPUT;
    global $BWLIMIT_DEPRIORATE;
    global $BWLIMIT_EXCEEDPOLICY;

    global $running_mode;
    global $somethingelse;
    global $useriplastseen;

    echo "checking quotas now...\n";
    
    echo "Dump of user last seen ip table ==== ...\n";
    var_dump($useriplastseen);

    $userlist_sql = "SELECT * FROM user_details";
    $userlist_result = mysql_query($userlist_sql);
    $userlist_assoc = null;

   

    $days_since_epoch_today = day_since_epoch(time());

    while(($userlist_assoc = mysql_fetch_assoc($userlist_result)) != null) {
        $username = $userlist_assoc['username'];
        $htbparentclass =  $userlist_assoc['htbparentclass'];

        $currently_within_quota = $userlist_assoc['within_quota'];
        echo "Doing quota check for $username ...\n";

        $bwusage_today_sql = "SELECT `usage` FROM `usage_logs` WHERE user = '$username'"
            . " AND dayindex = $days_since_epoch_today";
        $bwresult_today = mysql_query($bwusage_today_sql);
        $bwresult_assoc = mysql_fetch_assoc($bwresult_today);

        $within_quota = 1;

        //if this is a guest account so check if they are within time as well
        if($userlist_assoc['is_guest_acct'] == true) {
            if($userlist_assoc['expires_utime'] < time()) {
                //this account has expired
                $within_quota = 0;
            }
        }

        //check daily
        if($bwresult_assoc['usage'] > $userlist_assoc['daily_limit']) {
            //over quota, block and continue
            $within_quota = 0;
            if($BWLIMIT_DEBUGOUTPUT == true) {
                echo "Found user $username over daily quota: used " . $bwresult_assoc['usage']
                    . "b quota is only " . $userlist_assoc['daily_limit'] . "b\n";
            }
        }

        if($within_quota == 1) {
            //check weekly quota
            $week_usage = sum_bandwidth_usage(7, $days_since_epoch_today, $username);
            if($week_usage > $userlist_assoc['weekly_limit']) {
                $within_quota = 0;
                if($BWLIMIT_DEBUGOUTPUT) {
                    echo "Found user $username over weekly quota: used " . $week_usage
                        . "b quota is only " . $userlist_assoc['weekly_limit'] . "b\n";
                }
            }else {
                //check monthly quota
                $month_usage = sum_bandwidth_usage(30, $days_since_epoch_today, $username);
                if($month_usage > $userlist_assoc['monthly_limit']) {
                    $within_quota = 0;
                    if($BWLIMIT_DEBUGOUTPUT) {
                        echo "Found user $username over monthly quota: used " . $month_usage
                            . "b quota is only " . $userlist_assoc['monthly_limit'] . "b\n";
                    }
                }
            }
        }

        if($running_mode) {
            if($running_mode == "ByIP" && $useriplastseen[$username]) {
                $my_current_time = $useriplastseen[$username];
                $update_ip_last_seen_sql = "UPDATE user_sessions set last_ip_activity = $my_current_time "
                        . " WHERE username = '$username'";
                mysql_query($update_ip_last_seen_sql);
                $last_time_seen_formatted = date(DATE_RFC1036, $my_current_time);
                
                echo "Update useriplastseen for $username time = " .  $useriplastseen[$username] . " ($last_time_seen_formatted)\n";
            }
        }

        //TODO - check if they were within quota but are now out of quota to knock them out HERE
        $sql_quota_stat_update = "UPDATE `user_details` SET `within_quota` = $within_quota "
            . " WHERE `username` = '$username'";
        mysql_query($sql_quota_stat_update);

        //check and see if this is someone to deactivate...
        if($currently_within_quota == 1 && $within_quota ==0 && $BWLIMIT_EXCEEDPOLICY == "cutoff") {
	            echo "DEACTIVATE: $username has just exceeded quota on $userlist_assoc[active_ip_addr] \n";
        	    bwlimit_user_ip_control($username, $userlist_assoc['active_ip_addr'],
                	    false, true);
	}else if($BWLIMIT_EXCEEDPOLICY == "deprio" && $currently_within_quota != $within_quota) {
		//re or deprioritize
		$ceildown = $userlist_assoc['ceildown'];
		$ceilup = $userlist_assoc['ceilup'];
           	$rateup = $userlist_assoc['rateup'];
                $ratedown	= $userlist_assoc['ratedown'];
                
		if($within_quota == 0) {
			$rateup = $BWLIMIT_DEPRIORATE;
			$ratedown = $BWLIMIT_DEPRIORATE;
		}

		//check for dynamic rate 
		$dynamic_rate_query = "SELECT useDynamicRates, SpeedFactorUp, SpeedFactorDown from process_log";
	        $dynamic_rate_result = mysql_query($dynamic_rate_query);
        	$dynamic_rate_arr = mysql_fetch_assoc($dynamic_rate_result);
	       	if($dynamic_rate_arr['useDynamicRates'] == 1) {
	               	$factordown = floatval($dynamic_rate_arr['SpeedFactorDown']);
                	$ratedown = intval(floatval($ratedown) * $factordown);
        	        $ceildown = intval(floatval($ceildown) * $factordown);
                	$factorup = floatval($dynamic_rate_arr['SpeedFactorUp']);
	                $rateup = intval(floatval($rateup) * $factorup);
        	        $ceilup = intval(floatval($ceilup) * $factorup);
		}

                //find active 
                $user_active_sessions_sql = "SELECT * FROM user_sessions WHERE username = '$username'";
                $user_active_sessions_result = mysql_query($user_active_sessions_sql);
                $user_active_sessions_arr = null;
                
                $devcount = 0;
		while(($user_active_sessions_arr = mysql_fetch_assoc($user_active_sessions_result))){
                        if($devcount == 0) {
                            $clientdel_cmd = "/usr/lib/bwlimit/htb-gen clear_username $username";
                            exec($clientdel_cmd);
                        }
			
			$readdcmd = "/usr/lib/bwlimit/htb-gen new_device $userlist_assoc[active_ip_addr] $ratedown $ceildown $rateup $ceilup $htbparentclass $username";
			exec($readdcmd);
			echo "Deprio: Ran $readdcmd\n";
			//mark the username
			$devcount++;
		}
        }
    }
}


/**
 *
 * Turns on and off access by IP
 *
 * @param <type> $username
 * @param <type> $ipaddr
 * @param <type> $active
 * @param <type> $forcerun - Force a run of the access controller (set to true for restoring service after masq restart)
 */
function bwlimit_user_ip_control($username, $ipaddr, $active, $forcerun = false, $login_method = "web") {
    $current_time = time();
    global $BWLIMIT_EXCEEDPOLICY;
    global $BWLIMIT_DEPRIORATE;

    //check the current status
    $current_status_sql = "SELECT user_details.username AS username, "
         . " user_details.ratedown AS ratedown, "
         . " user_details.ceildown AS ceildown, "
         . " user_details.rateup AS rateup, "
         . " user_details.ceilup AS ceilup, "
         . " user_sessions.active_ip_addr AS active_ip_addr, "
         . " user_sessions.last_ip_activity AS last_ip_activity, "
         . " user_details.blockdirecthttps "
         . "FROM user_details LEFT JOIN user_sessions ON user_details.username = user_sessions.username "
         . "WHERE user_details.username = '$username'";
    $current_status_result = mysql_query($current_status_sql);
    $current_status_arr = mysql_fetch_assoc($current_status_result);
 
    $check_active_now_sql = "SELECT active_ip_addr FROM user_sessions WHERE username = '$username' AND active_ip_addr = '$ipaddr' ";
    $check_active_now_result = mysql_query($check_active_now_sql);
    $num_results = mysql_num_rows($check_active_now_result);
    
    $currently_active = $num_results;
    $sql = "";
    
    //to make sure we are not duplicating stuff...
    $delete_session_sql = "";
    
    if($active) {
        /*
        $sql = "Update user_details set active_ip_addr = '$ipaddr', last_ip_activity = $current_time "
            . " , login_method = '$login_method', session_start_time = $current_time WHERE username = '$username'";
         * 
         */
        $delete_session_sql = "DELETE FROM user_sessions WHERE username = '$username' AND active_ip_addr = '$ipaddr'";
        $sql = "INSERT INTO user_sessions (username, active_ip_addr, last_ip_activity, session_start_time, login_method)"
                    .   "VALUES ('$username', '$ipaddr', '$current_time', '$current_time', '$login_method')";
    }else {
        //we need to deactivate, remove it from the ip list and call commands to
        //block the previously recorded ip
        //$sql = "Update user_details set active_ip_addr = '' WHERE username = '$username'";
        $sql = "DELETE FROM user_sessions WHERE username = '$username' AND active_ip_addr = '$ipaddr'";
    }
    
    if($delete_session_sql != "") {
        mysql_query($delete_session_sql);
    }
    
    //echo "setting IP using $sql \n";
    mysql_query($sql);

    //TODO: Activate IP tables rules etc.
    $iparg = "--deactivate";
    if($active == true) {
        
        $iparg = "--activate";
    }

    //make sure that we only do this if we need a change...
    if($currently_active != $active || $forcerun == true) {
	$ratedown = intval($current_status_arr['ratedown']);
	$ceildown = intval($current_status_arr['ceildown']);
	$rateup = intval($current_status_arr['rateup']);
	$ceilup = intval($current_status_arr['ceilup']);
	$blockdirecthttps = intval($current_status_arr['blockdirecthttps']);
        $htbparentclass = intval($current_status_arr['htbparentclass']);
    
	//if the user is not within quota this function should only have been called when deprio poliy is active
	//set their reserved rates to be only 'depriorate'
	if(user_within_quota($username) != 1) {
		$ratedown = intval($BWLIMIT_DEPRIORATE);
		$rateup = intval($BWLIMIT_DEPRIORATE);
	}

	//check and see if we are using dynamic rates
	
	$dynamic_rate_query = "SELECT useDynamicRates, SpeedFactorUp, SpeedFactorDown from process_log";
	$dynamic_rate_result = mysql_query($dynamic_rate_query);
	$dynamic_rate_arr = mysql_fetch_assoc($dynamic_rate_result);
	if($dynamic_rate_arr['useDynamicRates'] == 1) {
		$factordown = floatval($dynamic_rate_arr['SpeedFactorDown']);
		$ratedown = intval(floatval($ratedown) * $factordown);
		$ceildown = intval(floatval($ceildown) * $factordown);
		$factorup = floatval($dynamic_rate_arr['SpeedFactorUp']);
		$rateup = intval(floatval($rateup) * $factorup);
		$ceilup = intval(floatval($ceilup) * $factorup);
	}
        
        $ipcontrol_cmd = "/usr/lib/bwlimit/netspeedmanager_ipcontrol $iparg $ipaddr $ratedown $ceildown $rateup $ceilup $blockdirecthttps $username $htbparentclass";
        echo "Run: $ipcontrol_cmd \n";
        exec($ipcontrol_cmd);
        
        //make sure that any existing connections are terminated
        if($active == false) {
            $kill_cmd = "/usr/lib/bwlimit/netspeedmanager_killclient $ipaddr";
            exec($kill_cmd);
        }
    }


    return true;
}




/**
 * Simple utility function to determine if a user is within their quota or not
 * 
 * return 1 if yes, 0 otherwise
 */
function user_within_quota($username) {
    $lookup_sql = "SELECT within_quota from user_details";
    $lookup_result = mysql_query($lookup_sql);
    $lookup_arr = mysql_fetch_array($lookup_result);
    return intval($lookup_arr[0]);
}

/**
 * Check file size of http download
 */
function remote_filesize($url)
{
   ob_start();
   $ch = curl_init($url);
   curl_setopt($ch, CURLOPT_HEADER, 1);
   curl_setopt($ch, CURLOPT_NOBODY, 1);

   $ok = curl_exec($ch);
   curl_close($ch);
   $head = ob_get_contents();
   ob_end_clean();

   $regex = '/Content-Length:\s([0-9].+?)\s/';
   $count = preg_match($regex, $head, $matches);

   return isset($matches[1]) ? intval($matches[1]) : -1;
}

/**
* Look and see if we need to autoreset passwords 
*/
function check_autoreset_users() {
  $timestr = date("Ymd");
  $sql_query = "SELECT * FROM autoreset_users WHERE applyday = '$timestr' AND actioned = 0";
  $sql_result = mysql_query($sql_query);
  $sql_arr = null;

  $resetcount = 0;
  while(($sql_arr = mysql_fetch_assoc($sql_result)) != null) {
	$username = $sql_arr['username'];
	$password = $sql_arr['password'];
	$auid = $sql_arr['auid'];
	exec("/usr/lib/bwlimit/userpasswordreset_cron.sh $username $password");
	echo "   Auto Reset: $username / $password\n";
	$update_sql = "UPDATE autoreset_users SET actioned = 1 WHERE auid = $auid";
	mysql_query($update_sql);
	
	
	$user_update_sql = "update user_details set active_ip_addr = '' WHERE username = '$username'";
    mysql_query($user_update_sql);
    
    $delete_savedmac_sql = "DELETE FROM usersavedmacs WHERE username = '$username'";
    mysql_query($delete_savedmac_sql);

	$resetcount++;
  } 

  if($resetcount > 0) {
	//demand a full reset of iptables etc
	echo "Auto username and password reset ran - doing full reset\n";
	exec("/usr/lib/bwlimit/bwlimit-reset");
  }
}


/**
* Check and see if we have a graph data problem of any kind
*/
function graphcheck() {
    //time until we expect a good data set / get alarmed
    $gracetime = 600;
    $bwlimit_time = intval(trim(`cat /var/run/bwlimit/bwlimit_startup.time`));
    //if((time() - $bwlimit_time) > $gracetime) {
    if(TRUE) {
        $oldest_time = time() - $gracetime;
        $totalok = 1;
        $clientok = 1;
        $totalcheck_sql = "SELECT stamp_inserted FROM data_usage_total WHERE stamp_inserted > $oldest_time";
        echo "run $totalcheck_sql \n";
        $totalcheck_result = mysql_query($totalcheck_sql);
        
        if(mysql_fetch_assoc($totalcheck_result) == null) {
            echo "Found nothing in total result = $totalcheck_result first row looks not ok\n";
            $totalok = 0;
        }
        
        //check if there are active clients by looking at the directory.  Scan will return
        // .. and . as names, so length of array should be > 2
        $client_classes = @scandir("/var/current_BWL_clients");
        if($client_classes !== FALSE && sizeof($client_classes) > 2) {
            //there are active clients -there should be client data
            $sql_client_data = "SELECT username FROM data_usage WHERE stamp_inserted > $oldest_time LIMIT 4";
            $sql_client_data_result = mysql_query($sql_client_data);
            if(mysql_num_rows($sql_client_data_result) < 4) {
                $clientok = 0;
            }
        }
        
        if($totalok == 0 || $clientok == 0) {
            echo "WARNING: TOTALOK: $totalok / CLIENTOK : $clientok - resetting some things \n";
            #exec("/etc/init.d/masq restart");
            #exec("/usr/bin/sv restart nsmcalcbytes");
        }else {
            echo "Checked Graphs - LOOKS OK\n";
        }
    }else {
        echo "within grace time";
    }
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

    echo "Done with download function\n";
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

/*
 * Check to see if a given PID is still running
 */
function check_pid_running($pid) {
    $cmd = "ps $pid";
    exec($cmd, $output, $result);
    if(count($output) >= 2) {
        return true;
    }else {
        return false;
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
                    /*$byte_cmd = "/sbin/iptables -t mangle -L htb-gen.$dir -n -v -x | "
                            . "grep htb-gen.$dir-$username | grep '$ip_with_esc_codes ' | awk ' { print $1 }'";
                     * 
                     */
                    $byte_cmd="/usr/lib/bwlimit/nsmtest_getbytecount $dir $username $ip_with_esc_codes";
                    echo "byte command = $byte_cmd\n";
                    $byte_result = `$byte_cmd`;
                    echo "\t byte result = $byte_result\n";
                    if($byte_result != null && $byte_result != "") {
                        echo "\t\t its numerics\n";
                        $ipbytecount += $byte_result;
                    }
                }
                
                echo "Byte count $username / $user_session_arr[active_ip_addr] = $ipbytecount \n";
                
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

/**
 * Do ldap_connect as we are configured to do via the control
 * panel (nsm.conf.php)
 * 
 * @global type $LDAP_SERVER
 * @global type $LDAP_USESSL
 * @global type $LDAP_CHECKCERT
 * @global type $LDAP_BINDDN
 * @global type $LDAP_BINDPASS
 * @return type
 */
function bwlimit_ldap_connect() {
    global $LDAP_SERVER, $LDAP_USESSL, $LDAP_CHECKCERT;
            
    $ldapurl = $LDAP_SERVER;
    if($LDAP_USESSL == "yes") {
        $ldapurl = "ldaps://" . $LDAP_SERVER;
    }
    
    
    if($LDAP_CHECKCERT == "no") {
        putenv('LDAPTLS_REQCERT=never');
    }
    
    $ds = ldap_connect($ldapurl);
    echo "Connected with $ldapurl \n";
    
    return $ds;
}

/**
 * Bind to the LDAP connection represented by $ds 
 * with the management credentials (if any) in the settings
 * 
 * @global type $LDAP_BINDDN
 * @global type $LDAP_BINDPASS
 * @param type $ds
 * @return type
 */
function bwlimit_ldap_bind($ds) {
    global $LDAP_BINDDN, $LDAP_BINDPASS;
    $ldap_binddn = null;
    $ldap_pass = null;
    if(trim($LDAP_BINDDN) != "") {
        //ldap bind using credentials
        $ldap_binddn = trim($LDAP_BINDDN);
        $ldap_pass = $LDAP_BINDPASS;
    }
    
    $bind_result = ldap_bind($ds, $ldap_binddn, $ldap_pass);
    return $bind_result;
}

function bwlimit_ldap_getuserinfo($ds, $username, $attrs) {
    global $LDAP_SEARCHFILTER, $LDAP_BASEDN;
    $search_filter_str = str_replace('%username', $username, $LDAP_SEARCHFILTER);
    echo "Search str is: $search_filter_str for username $username\n";
    
    $search_result = null;
    if($attrs == null) {
        $search_result = ldap_search($ds, $LDAP_BASEDN, $search_filter_str);
    }else {
        $search_result = ldap_search($ds, $LDAP_BASEDN, $search_filter_str, $attrs);
    }
    
    echo "Number of entries returned is " . ldap_count_entries($ds, $search_result) . "\n";
    
    $search_info = ldap_get_entries($ds, $search_result);
    
    
    return $search_info;
}

/**
 * 
 * Remove all traces of this user from the Net Speed Manager system
 * 
 * @param type $username username to delete
 */
function bwlimit_delete_user($username) {
    $del_sql1 = "DELETE FROM user_details WHERE username = '$username'";
    mysql_query($del_sql1);
    
    $del_sql2 = "DELETE FROM user_sessions WHERE username = '$username'";
    mysql_query($del_sql2);
}

?>