#!/usr/bin/php5/php

<?php
/* 
 * This will do an FTP upload that was requested by the user
 *
 * Takes the transfer ID as the argument
 *
 */

require_once "/usr/lib/bwlimit/web/bwlimit_user_functions.php";
require_once "/usr/lib/bwlimit/bwlimit-functions.php";
require_once "/usr/lib/bwlimit/web/bwlimit_user_config.php";


echo "Connecting to database...";
connectdb();




$find_details_sql = "SELECT * FROM xfer_requests WHERE requestid = $argv[1]";
$find_details_result = mysql_query($find_details_sql);
$xfer_details = mysql_fetch_assoc($find_details_result);
$xfer_type = $xfer_details['type'];

if($xfer_type != "ftp_upload") {
    echo "Not an FTP Upload ! Abort!\n";
    exit(1);
}else {
    echo "OK FTP upload to be attempted\n";
}


$requestid = $argv[1]; 

//try and connect...
echo "Connecting to $xfer_details[ftp_hostname] ...\n";
$update_starting_sql = "Update xfer_requests SET status = 'starting...' WHERE requestid = $requestid";
mysql_query($update_starting_sql);


$conn = ftp_connect($xfer_details['ftp_hostname']);

//TODO : set auto seek


if($conn) {
    $login_result = ftp_login($conn, $xfer_details['ftp_username'], $xfer_details['ftp_pass']);
    ftp_pasv($conn, TRUE);
    
    echo "Logged in... Switching to passive mode...\n";

    
    if($login_result) {
        echo "Logged in OK!\n";
        //flush();
        //let's upload the file
        $local_filehandle = fopen($xfer_details['output_file'], "r");
        $remote_filename = basename($xfer_details['output_file']);

        $ret = ftp_nb_fput($conn, $remote_filename,  $local_filehandle, FTP_BINARY);

        //put into the database that it has started...
        $update_db_started_sql =
            "UPDATE xfer_requests set status = 'inprogress', comment = 'Upload started' "
            . "WHERE requestid = $xfer_details[requestid]";
        mysql_query($update_db_started_sql);

        while($ret == FTP_MOREDATA) {
            sleep(20);
            echo ".";
            $bytesuploaded = ftell($local_filehandle);
            //update the progress here...
            $update_status_sql =
                "UPDATE xfer_requests set comment = 'In Progress - Uploaded $bytesuploaded', "
                . "upload_count = $bytesuploaded WHERE requestid = $xfer_details[requestid]";
            mysql_query($update_status_sql);

            $ret = ftp_nb_continue($conn);
        }

        if($ret == FTP_FINISHED) {
            echo "Success - upload complete!\n";
            $update_complete_sql = "Update xfer_requests SET status = 'complete' WHERE requestid = $requestid";
            mysql_query($update_complete_sql);
        }else {
            $update_err_sql = "Update xfer_requests SET status = 'error - failure' WHERE requestid = $requestid";
            mysql_query($update_err_sql);
            echo "Oooops... failure....\n";
        }

    }else {
        echo "ERR: Invalid username/password";
        $update_err_sql = "Update xfer_requests SET status = 'error - no connection' WHERE requestid = $requestid";
        mysql_query($update_err_sql);
        exit(1);
    }
}




?>