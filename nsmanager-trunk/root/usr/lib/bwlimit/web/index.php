<?php
/*
 * This will log the user in
 */

require_once "../bwlimit-functions.php";
require_once "bwlimit_user_functions.php";

header("cache-control: private no-cache");
session_start();
connectdb();

?>

<html>
  <head>
    <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>
    <style type="text/css">
      body {
        margin: 0px;
        padding: 0px;
      }
      #container_upload {
        width : 300px;
        height: 200px;
        margin: 8px auto;
      }
      
      
      #container_download {
        width : 300px;
        height: 200px;
        margin: 8px auto;
      }
      
      #container_totaldown {
        width : 300px;
        height: 200px;
        margin: 8px auto;
      }
      
      #container_totalup {
        width : 300px;
        height: 200px;
        margin: 8px auto;
      }
      
      #ad{
		padding-top:220px;
		padding-left:10px;
      }
      
      .graphcell {
        padding: 10px;
        width: 320px;
      }
      
      .graphtitle {
        width: 320px;
        padding: 3px;
      }
    </style>
    
    <script type='text/javascript'>
        var bgColors = [ 'red', 'green' ];
        var statusTxt = [ 'DOWN', 'UP' ];
        
        xmlReqExtraParams = "&coninfo=y";
        
        function updateStatus(element) {
            var eleNames = ["internet", "isp_gateway", "domain_name"];
            
            for(var i = 0; i < eleNames.length; i++) {
                var val = parseInt(element.getAttribute(eleNames[i]));
                var targetEle = document.getElementById(eleNames[i]);
                targetEle.style.backgroundColor = bgColors[val];
                targetEle.innerHTML = statusTxt[val];
            }
            
            var speedcheckDown = Math.round((parseInt(element.getAttribute("speedcheckrx"))/1024)*8);
            var speedcheckUp = Math.round((parseInt(element.getAttribute("speedchecktx"))/1024)*8);
            
            document.getElementById("speedcheck_down_val").innerHTML = new String(speedcheckDown);
            document.getElementById("speedcheck_up_val").innerHTML = new String(speedcheckUp);
            var checkedDate = new Date();
            checkedDate.setTime(parseInt(element.getAttribute("speedchecktime")) * 1000);
            document.getElementById("speedcheck_stamp_inserted").innerHTML = checkedDate.toLocaleString();
        }

	    function showToolbar() {
                var popWinURL = "/bwlimit/bwlimit_user_toolbar.php";
                var newWin = window.open(popWinURL, "netspeedmanager_toolbar",
                    "width=150,height=650,toolbar=no,location=no");
        }
        
        function convertStrToUtime(fieldName) {
            var textFieldVal = document.forms[0][fieldName].value;

           	var dateTimeParts = textFieldVal.split(" ");

            var dateParts = dateTimeParts[0].split("/");
            var timeParts = dateTimeParts[1].split(":");

            var dateObj = new Date(parseInt(dateParts[0]),
                    parseInt(dateParts[1]),
                   	parseInt(dateParts[2]),
                    parseInt(timeParts[0]),
                    parseInt(timeParts[1]));
	    return (dateObj.getTime() / 1000);
       	}

    	function convertTime() {
                var fromTime = convertStrToUtime("theDate3");
               	document.forms[0].fromutime.value = fromTime;
               	var toTime = convertStrToUtime("theDate4");
                document.forms[0].toutime.value = toTime;
        }


    </script>
    
    <link type="text/css" rel="stylesheet" href="dhtmlgoodies_calendar/dhtmlgoodies_calendar.css?random=20051112" media="screen"></LINK>


	<script type="text/javascript" src="dhtmlgoodies_calendar/dhtmlgoodies_calendar.js?random=20060118"></script>
  </head>
  <body>
    <div id="maincontainer">
    
    <?php echo make_nsm_header(); ?>

<table>
    <tr>
        <td class="testheader">Local Area Network</td>
        <td class="testheader">Connection to ISP Gateway</td>
        <td class="testheader">Connection from ISP to Internet</td>
        <td class="testheader">DNS System</td>
    </tr>
    
    <tr>
        <td align='center' style='font: 16pt bold arial, sans-serif; color: white; background-color: green'>
            UP
        </td>
        <td id='isp_gateway' class='status' align='center' style='font: 16pt bold arial, sans-serif; color: white;'>
            
        </td>

        <td id='internet' class='status' align='center' style='font: 16pt bold arial, sans-serif; color: white;' >
            
        </td>
        
        <td id='domain_name' class='status' align='center' style='font: 16pt bold arial, sans-serif; color: white;' >
            
        </td>
    </tr>
</table>

<!-- Speed test results -->
<br/>&nbsp;
<br/>
<?php

$speedtest_sql = "SELECT * FROM speed_check ORDER BY stamp_inserted DESC LIMIT 1";
$speedtest_result = mysql_query($speedtest_sql);
$speedtest_arr = mysql_fetch_assoc($speedtest_result);



if($speedtest_arr) {
    $speeddown = intval(($speedtest_arr['rx'] / 1024) * 8);
    $speedup = intval(($speedtest_arr['tx'] / 1024) * 8);
    ?>
    
    <span id='speedresult_line'><b>ISP Speed Monitor result:</b> Download <span id='speedcheck_down_val'> <?php echo $speeddown; ?> </span> kbps / Upload <span id='speedcheck_up_val'> <?php echo $speedup; ?> </span> kbps</span>
    <span id="speedcheck_stamp_inserted">( checked <?php echo date("M/d/Y g:i", $speedtest_arr['stamp_inserted']);?> )</span>
    <?php
}else {
    ?>
    <i>Speed test has not run yet.  This runs every hour...</i>

<?php
}
?>

<span class='nsmbutton' onclick='bwcheckStart()'>Check Now</span>


<span id="speedcheck_popout" style='display: none; position: absolute; width: 180px; height: 100px; background-color: white; border: 2px solid black; padding: 10px;'>

<span id='speedcheck_password'>
    Admin Password:<input type='password' class='nsminputbox' id='speedcheck_passwordfield' length='10'/>
    <input type='button' class='nsminputbox' value='Start' onclick='start_test_request()'/>
    
    <input type='button' class='nsminputbox' value='Cancel' onclick="$('#speedcheck_popout').hide()"/>

    
    
</span>

<span id='speedcheck_wait' style='display: none'>
    <img src='waiting.gif' align='center'/><br/>
    Starting ... wait <span id='speedcheck_wait_time'> </span> seconds

</span>

<span id='speedcheck_count' style='display: none'>
    <img src='downloading.gif' align='center'/><br/>
    <br/>&nbsp;
    Download/Upload test running - wait <span id='speedcheck_count_time'> </span> seconds

</span>



</span>

<br/>&nbsp;
<br/>

<!-- Report request -->
<form name="input" action="get_connectivity_info.php" method="get" onsubmit='return convertTime()' target="_blank">


<table>
	<!-- TODO: Make this display the last week or something as a suggested range -->
	
	<script type='text/javascript'>
	
	    function padZero(num) {
	        if(num < 10) {
	            return "0" + num;
            }else {
                return num;
            }
        }
	
	    function fmtDateForInput(d) {
	        var retVal = d.getFullYear() + "/" + padZero(d.getMonth() + 1) + "/" + padZero(d.getDate())
	            + " " + padZero(d.getHours()) + ":" + padZero(d.getMinutes());
            return retVal;
	    }
	
	    var dateNow = new Date();
	    var suggestedFromDateStr = fmtDateForInput(dateNow);
	    var lastDate = new Date(dateNow.getTime() - (1000 * 60 * 60 * 24 * 7));//one week before
	    var suggestLastDateStr = fmtDateForInput(lastDate);
	    
		document.writeln('<tr><td>From: </td><td><input type="text" value="' + suggestedFromDateStr + '" readonly name="theDate4"><input type="button" value="Cal" onclick="displayCalendar(document.forms[0].theDate4,\'yyyy/mm/dd hh:ii\',this,true)"></td>');
		
        document.writeln('<td>to: </td><td><input type="text" value="' + suggestLastDateStr + '" readonly name="theDate3"><input type="button" value="Cal" onclick="displayCalendar(document.forms[0].theDate3,\'yyyy/mm/dd hh:ii\',this,true)"></td>');


    	</script>
	    <input type='hidden' name='fromutime'/>
	    <input type='hidden' name='toutime'/>

        <td><input type="submit" value="Get Speed &amp; Uptime Report "/></td></tr>
	
</table>
</form>
<a href="nsm_user_scheduledxfermgr.php">Schedule Download</a> |
<a href='#' onclick="showToolbar()">Show My Toolbar</a> | <a href='./current_bw_usage.php?section=daily'>Transfer Reports</a> | 
<a href='/server-manager/'>Admin Control Panel</a>

    
    <form action="" id='graphtypeform' name='graphtypeform'>
        <input type='radio' name='showtype' id='showGraphByUser' value='byuser' checked='checked' onchange='toggleGraphType()'/> By User |
        <input type='radio' name='showtype' id='showGraphByGroup' value='bygroup' onchange='toggleGraphType()'/> By Group
    </form>
    
    <table>
        <tr>
            <td class='graphtitle'>
                <h2>Download by user</h2>
                
            </td>
            
            <td rowspan='5' bgcolor='#aaaaaa'>
                &nbsp;
            </td>
            
            <td class='graphtitle'>   
                <h2>Total Downloads (entire connection)</h2>
                
            </td>
            
            <td rowspan='5' bgcolor='#aaaaaa'>
                &nbsp;
            </td>
            
            
            <td rowspan='5' width='300' valign='top'>
                <div id='userTable'>
                
                </div>
            </td>
        </tr>
        
        <tr>
            <td class='graphcell' valign='top'>
                <div id='container_download'></div>
            </td>
            
            <td class='graphcell' valign='top'>
                <div id="container_totaldown"></div>
            </td>
        </tr>
        
        <tr>
            <td class='graphtitle'>
                <h2>Upload by user</h2>
            </td>
            
            <td class='graphtitle'>
                 <h2>Total Uploads (entire connection)</h2>
            </td>
        
        </tr>
        
        <tr>
            <td class='graphcell'>
                
                <div id='container_upload'></div>
            </td>
            
            <td class='graphcell'>
               
                <div id="container_totalup"></div>
            </td>
        </tr>
        
        <tr>
            <td class='graphcell' valign='top'>
                <p>The above graphs show how the speed at which each user is downloading and uploading</p>
                
                <p>The administrator can control rates for each user through the admin control panel.</p>
            </td>
            
            <td class='graphcell' valign='top'>
                <p>The above graphs show the sum of downloads and uploads for all users - this is the sum of activity for the entire connection</p>
            </td>
            </td>
    </table>
    
    <script type="text/javascript" src="jquery-1.8.3.min.js"></script>
    <script type="text/javascript" src="jquery-ui-1.9.2.custom.min.js"></script>
    
    <script type="text/javascript" src="flotr2.min.js"></script>
    
    <script type='text/javascript' src='nsm_graph_functions.js'></script>
    <script type='text/javascript' src='nsm_speed_functions.js'></script>
    
    <script type='text/javascript'>
        
        doUserGroupXMLRequest();
        
    </script>
    
    <?php echo make_nsm_footer();?>
    </div>
  </body>
</html>
      
        
    
  
