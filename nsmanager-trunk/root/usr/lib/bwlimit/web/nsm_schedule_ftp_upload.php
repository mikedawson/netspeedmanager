<?php
/* 
 * This is to be used by users to request an upload to be done by FTP
 */
require_once "bwlimit_user_functions.php";
require_once "../bwlimit-functions.php";
require_once "bwlimit_user_config.php";

session_start();

connectdb();
$action = $_REQUEST['action'];

$scheduled_and_return = False;

if($action == 'schedule' && $_SESSION['user']) {
    //do the schedule of the upload

    
    $tmp_filename = $_FILES["file"]["tmp_name"];
    $actual_filename = $_FILES["file"]["name"];
    $filesize = $_FILES["file"]["size"];

    $tmp_pathinfo = pathinfo($tmp_filename);
    $assembly_dirname = "/var/lib/bwlimit/xfertmp/$_SESSION[user]";
    

    //make sure that the directory exists, if not create it
    $mkdir_ok = true;
    if(!is_dir($assembly_dirname)) {
        $mkdir_ok = mkdir($assembly_dirname);
    }

    $storage_filename = "";
    if($mkdir_ok) {
        $storage_filename = $assembly_dirname . "/" . $actual_filename;
        
        copy($tmp_filename, $storage_filename);
        
        $start_time = mktime(intval($_REQUEST['hrs']), intval($_REQUEST['mins']));
        if($start_time < $time_now) {
            $start_time += (60*60*24);
        }

        $total_size = filesize($storage_filename);
        $schedule_job_sql =
            "INSERT INTO xfer_requests (`url`, `user`, output_file, status, start_time, "
            . "comment, ftp_hostname, ftp_username, ftp_pass, type, total_size) VALUES ("

            . "'$actual_filename', '$_SESSION[user]', '$storage_filename', 'waiting', $start_time,"
            . "'Waiting until $_REQUEST[hrs]:$_REQUEST[mins] to start upload', "
            . "'$_REQUEST[ftp_hostname]', '$_REQUEST[ftp_username]', '$_REQUEST[ftp_pass]', 'ftp_upload', $total_size)";
        
        mysql_query($schedule_job_sql);
        $scheduled_and_return = True;
    }else {
        echo "Error copying file";
    }
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
        if(!$_SESSION['user']) {
            echo "Session Expired";
        }else if($scheduled_and_return == False) {
            //show the form here
            ?>

            <p>
                To upload a file please enter all the details below and select
                the file and the time that you want it to be uploaded.  To upload
                multiple files please put them in a zip first.
            </p>

            <form action='nsm_schedule_ftp_upload.php' method='post' enctype="multipart/form-data">
                <input type='hidden' name='action' value='schedule'>

                <table>
                    <tr>
                        <td>File:</td>
                        <td>
                            <input type="file" name="file"/>
                        </td>
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
                        <td>FTP Server Name:</td>
                        <td><input type='text' name='ftp_hostname' class='nsminputbox'/></td>
                    </tr>

                    <tr>
                        <td>FTP Username:</td>
                        <td><input type='text' name='ftp_username' class='nsminputbox'/></td>
                    </tr>

                    <tr>
                        <td>FTP Password:</td>
                        <td><input type='password' name='ftp_pass' class='nsminputbox'/></td>
                    </tr>



                </table>
                <input type='submit' value="Request Upload" class='nsmbutton'/>
            </form>

            

            <?php
        }else if($scheduled_and_return == True) {
            echo "Thank You! Your upload has been scheduled.  <br/><br/><a href='./nsm_user_scheduledxfermgr.php'>Click Here</a> to return";
        }
        ?>


        <?php echo make_nsm_footer(); ?>

        </div>
    </body>
</html>