<?php


require_once "../bwlimit-functions.php";

require_once "bwlimit_user_functions.php";

$BWLIMIT_SPEEDCHECK_STATUS_WAIT=0;
$BWLIMIT_SPEEDCHECK_STATUS_COUNT=1;
$BWLIMIT_SPEEDCHECK_STATUS_DONE=2;

header("Content-Type: text/xml");

echo "<?xml version='1.0'?>\n";


?>



<speedctrl>



<?php

$action = $_REQUEST['action'];

if($action == "start") {
    $pass=$_REQUEST['pass'];
    $auth_result=bwlimit_authenticate("admin", $pass);
    if($auth_result == true) {
        $auth_result = "1";
    }else {
        $auth_result = "0";
    }
    echo "<auth result='$auth_result'/>";
    
    if($auth_result == "1") {
        //TODO: Check for already running tests...
        
        connectdb();
        
        //see if there is an ongoing test
        $sql = "SELECT * FROM speedcheck_control WHERE inprogress = 1 AND (unix_timestamp() - timestarted) < ($BWLIMIT_SPEEDCHECK_WAITTIME + $BWLIMIT_SPEEDCHECK_COUNTTIME + 10)";
        $current_result = mysql_query($sql);
        if(mysql_num_rows($current_result) == 0) {
            exec("/usr/lib/bwlimit/forkCalcBandwidth");
            echo "<test id='testitem' starttime='" . time() . "' waittime='$BWLIMIT_SPEEDCHECK_WAITTIME' counttime='$BWLIMIT_SPEEDCHECK_COUNTTIME'/>";
        }
    }
    
    
}

?>

</speedctrl>

