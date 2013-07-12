<?php

header("Cache-Control: no-cache");
require_once "bwlimit_user_functions.php";
require_once "../bwlimit-functions.php";
session_start();
connectdb();

?>

<html>
    <head>
        <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>

    </head>

    <body>
        <div id="maincontainer">
            <?php echo make_nsm_header(); ?>

            <p>
                <form id='reqform' action="bwlimit_autoreset_password_actionit.php" method="POST">
                    
                    Admin password<input type="password" name='adminpass'/><br/>
                    <input type='radio' name='resettype' value='now'/>Now <br/>
                    <input type='radio' name='resettype' value='xdays'/>Daily for <input type='text' name='resetdays' size='2' value='1'/> days
                    <input type='submit' value='Submit'/>
                </form>
            </p>

             <?php echo make_nsm_footer();?>
        </div>
    </body>
</html>

