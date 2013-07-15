<?php
/* 
 * This page is used by the user to schedule a download, upload etc.
 */
require_once "bwlimit_user_functions.php";
require_once "../bwlimit-functions.php";
require_once "bwlimit_user_config.php";

connectdb();
check_login();


$action = $_REQUEST['action'];

$username = $_SESSION['user'];

if($action == 'schedule') {
    //schedule the xfer
    $urltodl = $_REQUEST['urlrequest'];
    $start_time_str = $_REQUEST['hrs'] . ":" . $_REQUEST['mins'];

    //convert this to utime.  If that means it's before now, add a day (e.g. start at 01:00am)
    $time_now = time();
    $start_time = mktime(intval($_REQUEST['hrs']), intval($_REQUEST['mins']));
    if($start_time < $time_now) {
        $start_time += (60*60*24);
    }

    $autopause = $_REQUEST['autopauseafter'];
    $time_limit = -1;
    if($autopause && $autopause == 'autopause') {
        $time_limit = intval($_REQUEST['limit_hrs']) * intval($_REQUEST['limit_mins']) * 60;

    }
    $filebasename = basename($urltodl);

    $outfile = "$BASEDLWORKINGPATH/$username/$filebasename";
    $destfile = "$BASESAVEPATH/$username/home/$filebasename";

    $downloadsize = remote_filesize($urltodl);

    $schedule_sql_insert = "INSERT INTO xfer_requests (url, `user`, `pid`, countedbytes, "
                . "total_size, output_file, dest_file, type, status, start_time, "
                . "stop_utime, comment) VALUES ('$urltodl', '$username', '-1', 0, "
                . "$downloadsize, '$outfile', '$destfile', 'http_download', 'waiting', $start_time, "
                . "$time_limit, 'Waiting until $start_time_str to start' )";
    
    mysql_query($schedule_sql_insert);
}

?>

<html>
    <head>
        <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>
        <title>Net Speed Manager Scheduled Transfer Request</title>

       
    </head>

    <body>
        <div id="maincontainer">
        <?php echo make_nsm_header(); ?>
        <?php
        if(!$username) {
            echo "Session Expired";
        }else if($action == 'schedule') {
            echo "OK - Return to scheduled transfer manager "
                . "<a href='nsm_user_scheduledxfermgr.php'>click here</a>";
        }else {
            //show the form to schedule a download
            ?>
            <p>
                Please enter the URL of the file that you would like to download...
            </p>
            <form action='nsm_schedule_xfer.php' method='post'>
                <input type='hidden' name='action' value='schedule'/>
                <table>
                    <tr>
                        <td>URL:</td>
                        <td><input type='text' name='urlrequest' size='128' class='nsminputbox'/>
                    </tr>

                    <tr>
                        <td>Start Time:</td>
                        <td>
                            <select name='hrs'>
                            <?php
                                for($hrs = 0; $hrs <= 23; $hrs++) {
                                    echo "<option value='$hrs'>$hrs</option>\n";
                                }
                            ?>
                            </select>
                            :
                            <select name='mins'>
                            <?php
                                for($mins = 0; $mins <= 59; $mins++) {
                                    echo "<option value='$mins'>$mins</option>\n";
                                }
                            ?>
                            </select>
                            
                        </td>
                    </tr>

                    <tr>
                        <td>Auto Pause:</td>
                        <td>

                            <input type='checkbox' name='autopauseafter' value='autopause'/>

                            Auto Pause After: 

                            <select name='limit_hrs'>
                            <?php
                                for($hrs = 0; $hrs <= 23; $hrs++) {
                                    echo "<option value='$hrs'>$hrs</option>\n";
                                }
                            ?>
                            </select> hrs
                            :
                            <select name='limit_mins'>
                            <?php
                                for($mins = 0; $mins <= 59; $mins++) {
                                    echo "<option value='$mins'>$mins</option>\n";
                                }
                            ?>
                            </select> mins

                        </td>
                    </tr>
                </table>

                <input type='submit' value="Request Download" class='nsmbutton'/>
            </form>


            <?php
            
        }
        ?>

        <?php echo make_nsm_footer(); ?>
        </div>
    </body>
</html>