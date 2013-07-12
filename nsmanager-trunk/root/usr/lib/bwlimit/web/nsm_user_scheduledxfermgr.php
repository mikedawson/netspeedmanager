<?php
/*
 * This page shows the user a list of their scheduled transfers and then allows
 * them to cancel / pause / reschedule and resume them
 *
 */
require_once "bwlimit_user_functions.php";
require_once "../bwlimit-functions.php";
require_once "bwlimit_user_config.php";

connectdb();

$action = $_REQUEST['action'];

if($action == "pause") {
    $request_to_pause =  $_REQUEST['xferid'];

    $pause_update_sql = "UPDATE xfer_requests SET status='req_pause', "
        . "comment = 'Waiting for server to pause download...' "
        . "WHERE requestid = "
        . "\"$request_to_pause\" AND user = '$_SESSION[user]'";
    mysql_query($pause_update_sql);
    echo "Attempted pause using $pause_update_sql\n";
}else if($action == 'reschedule') {
    $request_to_resched = $_REQUEST['xferid'];
    $newtime = $_REQUEST['newtime'];

    //now convert the new time to unix time
    $timeparts = explode(":", $newtime);
    $newtime_hrs = $timeparts[0];
    $newtime_mins = $timeparts[1];

    $newtime_utime = mktime($newtime_hrs, $newtime_mins);

    $reschedule_sql = "UPDATE xfer_requests SET start_time = $newtime_utime, "
        . " status = 'waiting', Comment = 'Waiting until $newtime_hrs:$newtime_mins to start' "
        . " WHERE requestid = $request_to_resched AND `user` = '$_SESSION[user]'";
    mysql_query($reschedule_sql);
}

?>


<html>
    <head>
        <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>
        <title>Net Speed Manager Scheduled Transfer Request</title>

         <script type='text/javascript'>
            function reschedule(requestid) {
                var newTime = window.prompt('What time would you like to start the ' +
                    'download? Enter in hh:mm');
                if ( typeof(newTime) != "undefined" ) {
                    document.location.href = "./nsm_user_scheduledxfermgr.php?action=reschedule"
                        + "&xferid=" + requestid + "&newtime=" + encodeURI(newTime);
                }

            }

        </script>
    </head>

    <body>
        <div id="maincontainer">

        

        <?php echo make_nsm_header(); ?>

            <h2>Scheduled Transfer Manager</h2>

        <p>
            Here you can schedule downloads and uploads to happen anytime you want!<br/>
            After you have scheduled a transfer you don't have leave your computer connected
            - Net Speed Manager will take care of it for you.  For downloads when the download
            is complete you can find it in your home network folder.
            <br/>&nbsp;
        </p>

        &nbsp;&nbsp;<a href="nsm_schedule_xfer.php">Schedule a new download</a> |
        <a href="nsm_schedule_ftp_upload.php">Schedule FTP Upload</a><br/>
        <br/>&nbsp;
        <?php
        if(!$_SESSION['user']) {
            echo "Session Expired";
        }else {
            $username = $_SESSION['user'];

            //show the table
            $userdownloadtable = make_scheduled_xfer_table($username, false, "./nsm_user_scheduledxfermgr.php");
            echo $userdownloadtable;
        }

        echo make_nsm_footer();
        ?>
        </div>

   </body>
</html>