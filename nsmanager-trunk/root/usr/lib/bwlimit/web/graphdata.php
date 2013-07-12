<?php

header('Content-type: application/xml');
header("Cache-Control: no-cache");


echo  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";

require_once "/etc/nsm.conf.php";



$oldest_time = 0;
$last_arr;
$client_username = "";

//the last time for which the calcbyte loop ran and completed totally
$lastcalcbytetime = 0;

function write_totals() {
    global $oldest_time;
    global $lastcalcbytetime;

    $sql_query = " SELECT dlspeed, ulspeed, stamp_inserted FROM data_usage_total WHERE stamp_inserted > $oldest_time";
    $sql_result = mysql_query($sql_query);
    $arr_assoc = null;
    
    $xmlstr = "<totals>";
    
    while(($arr_assoc = mysql_fetch_assoc($sql_result)) != null) {
        $xmlstr .= "<usage time='$arr_assoc[stamp_inserted]' kbps_up='$arr_assoc[ulspeed]' kbps_down='$arr_assoc[dlspeed]'/>\n";
    }
    
    $xmlstr .= "</totals>";
    
    return $xmlstr;
}

/*
*/
function write_clients() {
    global $oldest_time;
    global $last_arr;
    global $client_username;
    global $lastcalcbytetime;
    
    $xmlstr = "<clients>\n";
    


    $where_additional = " AND stamp_inserted <= $lastcalcbytetime";
    if($client_username != "") {
        $where_additional .= " AND username = '$client_username'";
    }
    
    $sql_query = "select distinct username AS username from data_usage where stamp_inserted > $oldest_time $where_additional";
	$result = mysql_query($sql_query);
    $arr_assoc = null;

    while(($arr_assoc = mysql_fetch_assoc($result)) != null) {
        
        $current_username = $arr_assoc["username"];
        
        
        if($current_username == null | $current_username == "") {
            continue;
        }
        
                
        $perclient_sql = "select kbps_up,kbps_down,stamp_inserted from data_usage WHERE username = '$current_username' AND stamp_inserted > $oldest_time ORDER BY stamp_inserted";
        
        $perclient_result = mysql_query($perclient_sql);
        
        $perclient_arr = null;
        $xmlstr .= "<client username='$current_username'>\n";
        while(($perclient_arr = mysql_fetch_assoc($perclient_result)) != null) {
            $xmlstr .= "<usage time='$perclient_arr[stamp_inserted]' kbps_up='$perclient_arr[kbps_up]' kbps_down='$perclient_arr[kbps_down]'/>\n";
            //TODO: Verify this really is the last time we know about... or change calcbytes to put in the same time for all (better)
            $last_arr = $perclient_arr;
        }
        $xmlstr .= "</client>\n";
        
    }
    
    $xmlstr .= "</clients>\n";
    return $xmlstr;
}


$q=$_GET["q"];
mysql_connect("localhost","bwlimit",$BWLIMIT_DBPASS);


mysql_select_db("bwlimits");

if($_GET['timesince']) {
    $oldest_time = intval($_GET['timesince']);
}else {
    $oldest_time = time() - intval($q);
}

if($_GET['client_username']) {
    $client_username = $_GET['client_username']; 
}

//find out the last time that calcbytes ran for
$lastcalcbytetime_result = mysql_query("select lastcalcbytetime from process_log");
$lastcalcbytetime_arr = mysql_fetch_assoc($lastcalcbytetime_result);
$lastcalcbytetime = $lastcalcbytetime_arr['lastcalcbytetime'];

$xferinfo_additional = "";


    //find out currnet connection status
    $speed_query = "SELECT * FROM data_usage_total ORDER BY stamp_inserted DESC LIMIT 1";
    $speed_result = mysql_query($speed_query);
    $speed_arr = mysql_fetch_assoc($speed_result);
    
    $xferinfo_additional = " dlspeed='$speed_arr[dlspeed]' ulspeed='$speed_arr[ulspeed]' ";
    
    $status_query = "SELECT * FROM connectivity_check ORDER BY stamp_inserted DESC LIMIT 1";
    $status_result = mysql_query($status_query);
    $status_arr = mysql_fetch_assoc($status_result);
    
    $speedcheck_query = "SELECT tx,rx,stamp_inserted FROM speed_check ORDER BY stamp_inserted DESC LIMIT 1";
    $speedcheck_result = mysql_query($speedcheck_query);
    $speedcheck_arr = mysql_fetch_assoc($speedcheck_result);
    
    $note_query = "SELECT connection_note FROM process_log";
    $note_result = mysql_query($note_query);
    $note_arr = mysql_fetch_assoc($note_result);
 
    $xferinfo_additional .= " connote='$note_arr[connection_note]' constatus='$status_arr[total_connectivity]' isp_gateway='$status_arr[ISP_gateway]' domain_name='$status_arr[domain_name]' internet='$status_arr[internet]' speedchecktime='$speedcheck_arr[stamp_inserted]' speedcheckrx='$speedcheck_arr[rx]' speedchecktx='$speedcheck_arr[tx]' ";
    



echo "<xferinfo $xferinfo_additional>";
echo write_clients();
echo write_totals();
echo "<lasttime time='" . $lastcalcbytetime . "'/>";
echo "</xferinfo>";
?>
