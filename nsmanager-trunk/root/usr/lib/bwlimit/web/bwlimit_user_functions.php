<?php
/* 
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
require_once "../bwlimit-config.php";
require_once "../bwlimit-functions.php";

session_start();

/**
 * This authentication uses the proc_open command to call the squid pam authenticator
 * (hard coded location is /usr/lib/squid/pam_auth - should be correct for all
 * distros
 * 
 * It writes the username and password to the pipe and then reads the response.
 * If the response is OK this means authentication succeeded and returns true
 * 
 * Otherwise it will return false
 * 
 * Importantly this avoids the username / password ever being visible on the
 * command line.
 * 
 * One must be careful of file permissions on the pam_auth command!
 *
 * @param <type> $username Username to authenticate
 * @param <type> $pass Password to authenticate
 */
function bwlimit_authenticate($username, $pass) {
    global $LDAP_AUTOADD, $LDAP_ENABLED;
    $errormsg = "";
    $auth_result = false;
    
    //check and see where the authentication for this account should come from
    $check_authsource_sql = "SELECT authsource FROM user_details WHERE username = '"
            . mysql_real_escape_string($username) . "'";
    
    $check_authsource_result = mysql_query($check_authsource_sql);
    
    if(mysql_num_rows($check_authsource_result) >= 1) {
        $check_authsource_arr = mysql_fetch_assoc($check_authsource_result);
        $authsource = $check_authsource_arr['authsource'];

        if($authsource == "local") {
            $auth_result = bwlimit_authenticate_local($username, $pass);
        }else {
            //we need to use ldap for this one
            $auth_result = bwlimit_authenticate_ldap($username, $pass);
        }
    }else {
        //see if we have ldap and auto add enabled
        if($LDAP_ENABLED == "yes" && $LDAP_AUTOADD == "yes") {
            //this might be a new account to add
            $ldap_result = bwlimit_authenticate_ldap($username, $pass);
            if($ldap_result == 1) {
                //this is a new account - add it
            }
        }
    }
    
    return $auth_result;
}

/**
 * This will put a username into the users_to_add table such that it will then
 * be found by the cron job to add
 * 
 * @param type $username
 */
function bwlimit_request_newaccount_fromldap($username) {
    $insert_sql = "INSERT INTO users_to_add(username, requested_utime, source) VALUES ('"
            . mysql_real_escape_string($username) . "', " . time() . ", 'ldap')";
    mysql_query($insert_sql);
}

function bwlimit_authenticate_local($username, $pass) {
    //we are gonna use squid pam auth instead...
    $proc_descriptor = array(
        0 => array("pipe", "r"), //stdin is a pipe that the child will read from
        1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
        2 => array("pipe", "w") //stderr a pipe that will be written to
    );
    $cwd = "/tmp";
    $env = array();
    $process = proc_open("/usr/lib/squid/pam_auth", $proc_descriptor, $pipes);
    if(is_resource($process)) {
        // $pipes now looks like this:
        // 0 => writeable handle connected to child stdin
        // 1 => readable handle connected to child stdout
        fputs($pipes[0], "$username $pass\n");
        fclose($pipes[0]);

        $line = fgets($pipes[1]);
        proc_close($process);
        if(substr($line,0,2) == "OK") {
            $_SESSION['user'] = $username;
            return true;
        }

    }
    return false;
}

/**
 * Checks authentication against ldap
 * @param type $username
 * @param type $pass
 */
function bwlimit_authenticate_ldap($username, $pass) {
    
    global $LDAP_BASEDN, $LDAP_SEARCHFILTER;
    
    $ds = bwlimit_ldap_connect();
    $bind_result = bwlimit_ldap_bind($ds);
    echo "Bind results is $bind_result \n";
    
    $search_info = bwlimit_ldap_getuserinfo($ds, $username, null);
    
    $user_dn = $search_info[0]["dn"];
    
    echo "User dn is : $user_dn \n";
    
    ldap_unbind($ds);
    @ldap_close($ds);
    
    //now try and bind with the user dn
    $ds2 = bwlimit_ldap_connect();
    
    echo "Attempting bind with $user_dn with pass $pass \n";
    
    $result = @ldap_bind($ds2, $user_dn, $pass);
    @ldap_close($ds2);
    if($result == 1) {
        return 1;
    }else {
        return 0;
    }

}


/**
 * Should check and see if the user is logged in or not...
 *
 * First check for an active PHP session
 * Then check for an active session by querying active IP addresses
 * Then check to see if there are cookies with a saved username/password
 *
 * @return <type>
 */
function check_login() {
    global $ip_activity_timeout;


    //see is there an active session for them right now
    $srcip = $_SERVER[REMOTE_ADDR];
    $timesince = time() - $ip_activity_timeout;
    $find_ip_user_sql = "SELECT username FROM user_sessions WHERE active_ip_addr = '$srcip' "
        . " AND last_ip_activity > $timesince";
    $find_ip_result = mysql_query($find_ip_user_sql);
    $find_ip_arr = null;
    if(($find_ip_arr = mysql_fetch_assoc($find_ip_result))) {
        //this is an OK active session - do not require login again...
        $_SESSION['user'] = $find_ip_arr['username'];
        return true;
    }

    //check and see if there is a cookie here...
    /*
    if(isset($_COOKIE['bwlimits']) && isset($_COOKIE['bwlimits']['un'])) {    
        if(bwlimit_authenticate($_COOKIE['bwlimits']['un'],
                $_COOKIE['bwlimits']['pw']) == true) {
            $_SESSION['user'] = $_COOKIE['bwlimits']['un'];
            
            $new_ipaddr = $_SERVER[REMOTE_ADDR];
            
            bwlimit_user_ip_control($_SESSION['user'], $new_ipaddr,
                    true);
            return true;
        }
    }
    */
    return false;
}

function make_nsm_header() {
    $output = "<table cellpadding='0' cellspacing='0' border='0'><tr><td valign='top'>"
        . "<img src='nsmlogo120.png' alt='Net Speed Manager'/></td>"
        . "</tr></table>";
    return $output;

}

function make_nsm_footer() {
    $output = "<span class='copyright_notice'>Net Speed Manager Copyright &copy; 2009-2012"
        . " PAIWASTOON Networking Services Ltd. of Kabul, Afghanistan."
        . " </span>";
    return $output;
}

/*
 * This will make a table showing scheduled transfer requests
 *
 * Username can be null to show all user downloads
 *
 * username - username to get downloads of
 * has_username_col - whether or not to have a column in the table with the username
 * base_url = the base url (before the ?) to use
 */
function make_scheduled_xfer_table($username, $has_username_col = false, $base_url = "./") {
    $where_clause = " ";
    if($username != null) {
        $where_clause = " WHERE user = '$username' ";
    }

    $xfer_user_sql = "SELECT * FROM xfer_requests $where_clause ORDER by requestid DESC";
    $scheduled_xfer_results = mysql_query($xfer_user_sql);
    $output = "";


    $output .= "<table id='xfertable'><tr><th>Time</th><th>Status</th><th>Size</th><th>URL</th><th>Remarks</th><th>Action</th></tr>\n";
    $row = null;


    while(($row = mysql_fetch_assoc($scheduled_xfer_results)) != null) {
        $status = $row['status'];
        $requestid = $row['requestid'];
        $time_formatted = date("H:i", $row['start_time']);
        $output .= "<tr><td>$time_formatted</td>"
                    . "<td>$row[status]</td>"
                    . "<td>" . intval($row[total_size]/1024) . " KB</td>"
                    . "<td>$row[url]</td>"
                    . "<td>$row[comment]</td>"
                    . "<td>";

        //now make options to give the user
        if($status == 'inprogress') {
            $output .= " <a href=\"$base_url?action=pause&amp;xferid=$requestid\">Pause</a>";
        }else if($status == 'waiting' || $status == 'pause') {
            $output .= " <a href='#' onclick='reschedule($requestid)'>Reschedule</a> ";
        }
    }

    $output .= "</table>";

    return $output;
}

function get_bwinfo($username) {
    $userdetail_sql = "SELECT * FROM user_details WHERE username = '$username'";
    $userdetail_result = mysql_query($userdetail_sql);
    $userdetail_assoc = mysql_fetch_assoc($userdetail_result);

    //find out quota and actual use
    $days_since_epoch_today = day_since_epoch(time());
    $bwinfo = array();

    $bwinfo['daily'] = array();
    $bwinfo['daily']['used'] = sum_bandwidth_usage(1, $days_since_epoch_today, $username);
    $bwinfo['daily']['quota'] = $userdetail_assoc['daily_limit'];
    $bwinfo['daily']['status'] = set_quota_status($bwinfo['daily']);
    $bwinfo['daily']['saved_bytes'] = sum_bandwidth_usage(1, $days_since_epoch_today, $username, "saved_bytes");
    $bwinfo['daily']['saved_time'] = sum_bandwidth_usage(1, $days_since_epoch_today, $username, "saved_time");
    $bwinfo['daily']['usage_bytes'] = sum_bandwidth_usage(1, $days_since_epoch_today, $username, "usage_bytes");


    $bwinfo['weekly'] = array();
    $bwinfo['weekly']['used'] = sum_bandwidth_usage(7, $days_since_epoch_today, $username);
    $bwinfo['weekly']['quota'] = $userdetail_assoc['weekly_limit'];
    $bwinfo['weekly']['status'] = set_quota_status($bwinfo['weekly']);
    $bwinfo['weekly']['saved_bytes'] = sum_bandwidth_usage(7, $days_since_epoch_today, $username, "saved_bytes");
    $bwinfo['weekly']['saved_time'] = sum_bandwidth_usage(7, $days_since_epoch_today, $username, "saved_time");
    $bwinfo['weekly']['usage_bytes'] = sum_bandwidth_usage(7, $days_since_epoch_today, $username, "usage_bytes");

    $bwinfo['monthly'] = array();
    $bwinfo['monthly']['used'] = sum_bandwidth_usage(30, $days_since_epoch_today, $username);
    $bwinfo['monthly']['quota'] = $userdetail_assoc['monthly_limit'];
    $bwinfo['monthly']['status'] = set_quota_status($bwinfo['monthly']);
    $bwinfo['monthly']['saved_bytes'] = sum_bandwidth_usage(30, $days_since_epoch_today, $username, "saved_bytes");
    $bwinfo['monthly']['saved_time'] = sum_bandwidth_usage(30, $days_since_epoch_today, $username, "saved_time");
    $bwinfo['monthly']['usage_bytes'] = sum_bandwidth_usage(30, $days_since_epoch_today, $username, "usage_bytes");

    return $bwinfo;
}


//Possible status codes for bandwidth usage feedback to users
$STATUS_GREEN = 0;
$STATUS_YELLOW = 1;
$STATUS_RED = 2;

connectdb();

$threshold_check_sql = "SELECT red_warning_level, yellow_warning_level FROM process_log";
$threshold_check_result = mysql_query($threshold_check_sql);
$threshold_check_arr = mysql_fetch_assoc($threshold_check_result);

$red_warning_threshold  = floatval($threshold_check_arr['red_warning_level']);
$yellow_warning_threshold = floatval($threshold_check_arr['yellow_warning_level']);



/**
 * Expects an array with 'used' and 'quota'
 * @param <type> $quota_arr
 */
function set_quota_status($quota_arr) {
    global $red_warning_threshold;
    global $yellow_warning_threshold;
    global $STATUS_GREEN;
    global $STATUS_RED;
    global $STATUS_YELLOW;

    $percent_used = ($quota_arr['used'] / $quota_arr['quota']);

    if($percent_used > $red_warning_threshold) {
        $quota_arr['status'] = $STATUS_RED;
    }else if($percent_used > $yellow_warning_threshold) {
        $quota_arr['status'] = $STATUS_YELLOW;
    }else {
        $quota_arr['status'] = $STATUS_GREEN;
    }

    return $quota_arr['status'];
}


?>
