<?php


require_once "/etc/nsm.conf.php";
require_once "bwlimit_user_functions.php";

function make_result_cell($rowval) {
	$bg_color = "red";	
	$txt = "DOWN";
	
	if($rowval == 1) {
		$bg_color = "green";
		$txt = "UP";
	}

	return "<td class='checkcell' style='background-color: $bg_color ; color: white; font-weight: bold'>$txt</td>";
}

function make_result_row($row, $last_loop_time, $last_changed_time, $last_known_values) {
	$timenow = $row['stamp_inserted'];
        //$timestr = date("M/d/Y g:i",$last_changed_time) . " - " date("M/d/Y g:i",$last_loop_time);
        $timestr = date("M/d/Y g:i", $last_changed_time) . " to " . date("M/d/Y g:i", $last_loop_time);
        $str = "<tr><td>$timestr</td>";
	$str .= make_result_cell($last_known_values['ISP_gateway']);
	$str .= make_result_cell($last_known_values['internet']);
	$str .= make_result_cell($last_known_values['domain_name']);
	$str .=	make_result_cell($last_known_values['total_connectivity']);
	$str .= "</tr>";
	return $str;	
}


$con = mysql_connect("localhost",$BWLIMIT_DBUSER,$BWLIMIT_DBPASS);
if (!$con)
  {
  die('Could not connect: ' . mysql_error());
  }



mysql_select_db("bwlimits", $con);
$theDate3=$_GET["theDate3"];
$theDate4=$_GET["theDate4"];

$date_time_from = explode(" ",$theDate3);
$date_time_to = explode(" ",$theDate4);
$date_from=explode("/",$date_time_from[0]);
$time_from=explode(":",$date_time_from[1]);
$date_to=explode("/",$date_time_to[0]);
$time_to=explode(":",$date_time_to[1]);



$from_unixtime=mktime ($time_from[0],$time_from[1],0,$date_from[1], $date_from[2],$date_from[0]);
$to_unixtime=mktime ($time_to[0],$time_to[1],0,$date_to[1], $date_to[2],$date_to[0]);


$query_string= "select * from  connectivity_check where stamp_inserted between " . $from_unixtime . " and " . $to_unixtime;

$result = mysql_query($query_string);

$last_known_values = array();
$firstloop = 1;
$timefollower1=0;
$timefollower2=0;
$connectivity_follower=0;
$changestart=date("M/d/Y g:i",$from_unixtime);

$totalup = 0;
$totaldown = 0;



$first_row = mysql_fetch_array($result);
$last_known_values = $first_row;
$last_changed_time = $first_row['stamp_inserted'];
$last_loop_time = $first_time['stamp_inserted'];
$fields_to_check=array("total_connectivity","internet", "domain_name", "ISP_gateway");


if($first_row['total_connectivity'] == 1) {
	$totalup = 1;
}else {
	$totaldown = 1;
}

?>

<html>
<head>
    <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>
    
    <style type='text/css'>
        #speedtest_graph_container {
        width : 600px;
        height: 300px;
        margin: 8px auto;
      }
    </style>
</head>

<body>
<div id='maincontainer'>

<script type="text/javascript" src="flotr2.min.js"></script>

<?php echo make_nsm_header(); ?>

<h2>Connectivity Report</h2>

<?php

$timestr = "";

$tablestr = "<table border='1'><tr><td><b>Time Range</b></td><td><b>Gateway</b></td><td><b>IP 
Ping</b></td><td><b>DNS</b></td><td><b>Connectivity</b></td></tr>";

while(($row = mysql_fetch_array($result)) != NULL) {
	$changed = 0;
	foreach($fields_to_check as $current_field) {
		if($last_known_values[$current_field] != $row[$current_field]) {
			$changed = 1;
		}
	}

	
	if($row['total_connectivity'] == 1) {
	        $totalup = $totalup + 1;
	}else {
        	$totaldown = $totaldown + 1;
	}
	
	//if the difference between two timestamps is greater - server is considered off
	$timeOffThreshold = 300;
	
	if(($row['stamp_inserted'] - $last_loop_time) > $timeOffThreshold && $last_loop_time != 0) {
	    $timestr = date("M/d/Y g:i", $last_loop_time) . " to " . date("M/d/Y g:i", $row['stamp_inserted']);
	    $tablestr .= "<tr><td>$timestr</td><td colspan='4'>Server was off</td></tr>";
	    
	    $changed = 1;
	}


	
	if($changed == 1) {
		$timenow = $row['stamp_inserted'];
		$tablestr .= make_result_row($row, $last_loop_time, $last_changed_time, $last_known_values);
		$last_known_values = $row;
		$last_changed_time = $timenow;
	}
	$last_loop_time = $row['stamp_inserted'];
}





//last result
$timestr = "$last_changed_time to $last_loop_time";
//echo "<td>$timestr</td><td>Gateway</td><td>IP Ping</td><td>DNS</td><td>$last_known_values[total_connectivity]</td></tr>";
$tablestr .= make_result_row($row, $last_loop_time, $last_changed_time,	$last_known_values);
$tablestr .= "</table>";

$totalrows = $totalup + $totaldown;
echo "<br/><strong>Total Period Uptime: " . round(($totalup / $totalrows)*100, 2) . "% </strong> <br/><br/>";

?>
<table><tr><td>
<div id='speedtest_graph_container'></div>
</td></tr></table>


<?php

echo "<h2>Uptime monitoring data</h2> $tablestr";


//speed checks
$speed_check_sql = "SELECT * from speed_check where stamp_inserted between " . $from_unixtime . " and " . $to_unixtime 
	. " ORDER BY stamp_inserted  ";

$speed_result = mysql_query($speed_check_sql);
$speed_arr_assoc = null;

?>



<h2>Speed Check Results</h2>

<table border='1'>
<tr><td>Check Time</td><td>Download Speed</td><td>Upload Speed</td></tr>

<?php


$scriptStr = "";

while(($speed_arr_assoc = mysql_fetch_assoc($speed_result)) != NULL) {
	$timestamp = date("M/d/Y g:i", $speed_arr_assoc['stamp_inserted']);
	$dlspeed = ($speed_arr_assoc['rx']/1000)*8;
	$ulspeed = ($speed_arr_assoc['tx']/1000)*8;
	echo "<tr><td>$timestamp</td><td>$dlspeed</td><td>$ulspeed</td></tr>";
	
	$scriptStr .= "downloadDataPts[downloadDataPts.length] = [ $speed_arr_assoc[stamp_inserted] ,  Math.round($speed_arr_assoc[rx]/1000) * 8 ] ;\n";
	$scriptStr .= "uploadDataPts[uploadDataPts.length] = [ $speed_arr_assoc[stamp_inserted] ,  Math.round($speed_arr_assoc[tx]/1000) * 8 ] ;\n";
	
}

echo "</table>";
echo "<br/><br/>";
?>


<script type='text/javascript'>
var downloadDataPts = [];
var uploadDataPts = [];
<?php echo $scriptStr; ?>
(function () {

var timeformatter = function(x){
                    var x = parseInt(x);
                    var myDate = new Date(x*1000);
                    var string = myDate.getFullYear();
                    var mins = myDate.getMinutes();
                    if(mins < 10) {
                        mins = "0" + mins;
                    }
                    string = string + "-" + (myDate.getMonth()+1) + "-" + myDate.getDate() + " " + myDate.getHours() + ":" + mins;
                    result = string;
                    return string;
                    
                    //return x;
                }


var options = { 
    title : "ISP Speed Monitor", 
    HtmlText : false,
    xaxis : { 
        mode: "time", 
        labelsAngle : 45,  
        title: "Date", 
        tickFormatter : timeformatter 
    } ,
    yaxis : { 
        title : "Speed (kbps)", 
        titleAngle : 90,
        min: 0
    }
    
};

var flotrData = [ { label : "Download", data: downloadDataPts }, { label : "Upload", data : uploadDataPts } ];

Flotr.draw(document.getElementById("speedtest_graph_container"), flotrData, options);
})();
</script>




<?php echo make_nsm_footer();?>
</div>
</body>
</html>
