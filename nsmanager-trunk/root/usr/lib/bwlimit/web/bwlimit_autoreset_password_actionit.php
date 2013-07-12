<?php

header("Cache-Control: no-cache");
require_once "bwlimit_user_functions.php";
require_once "../bwlimit-functions.php";
require_once "bwlimit_autoreset_password_functions.php";

session_start();
connectdb();

$resettype = $_REQUEST['resettype'];
$resetdays = $_REQUEST['resetdays'];
$adminpass = $_REQUEST['adminpass'];

if(bwlimit_authenticate("admin", $adminpass)) {

    $fromutime = 0;


    if($resettype == "now") {
        $fromutime = time();
        $resetdays = 1;
    }else {
        $fromutime = time() + (60 * 60 * 24);//start tomorrow
        $resetdays = intval($resetdays);
    }


    $table_html = autoreset_generate_passwords($fromutime, $resetdays);
}else {
    $table_html = "Sorry - invalid admin password - please go back and try again";
}

?>

<html>
    <head>
        <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>

    </head>

    <body>
        <div id="maincontainer">
            <?php
            
            echo $table_html;
            
            ?>

            

            
        </div>
    </body>
</html>

