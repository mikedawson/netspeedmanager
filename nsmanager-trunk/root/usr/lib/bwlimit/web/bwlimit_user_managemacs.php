<?php
/*
 * This page is used by the user to schedule a download, upload etc.
 */
require_once "bwlimit_user_functions.php";
require_once "../bwlimit-functions.php";
require_once "bwlimit_user_config.php";

connectdb();

$action = $_REQUEST['action'];

$username = $_SESSION['user'];
?>

<html>
    <head>
        <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>
        <title>Net Speed Manager Scheduled Transfer Request</title>
        <script type="text/javascript">
            function checkDeleteMac() {
                return confirm("Are you sure you want to delete this computer from the list?");
            }
        </script>

    </head>

    <body>
        <div id="maincontainer">
        <?php echo make_nsm_header(); ?>

            <p>
                Here you can manage the computers / network cards which will be automatically
                logged in as you.  If you want to add a computer to the list then when you
                are prompted to login please click the remember checkbox and then type a name
                for that computer.
            </p>
            <?php
            if(!$_SESSION['user']) {
                echo "Session Expired";
            }else {
                //see if there is something to delete
                if($action && $action != null) {
                    if($action == "delete") {
                        $delete_sql = "DELETE from usersavedmacs WHERE username = '$username' "
                            . " AND macaddr = '" . mysql_escape_string($_REQUEST['delete']) . "'";
                        mysql_query($delete_sql);
                    }
                }


                $findusermacs = "SELECT * FROM usersavedmacs WHERE username = '$username'";
                $findusermacs_result = mysql_query($findusermacs);
                if(mysql_num_rows($findusermacs_result) < 1) {
                    echo "<i>You currently have not saved any computer hardware (MAC) addresses</i>";
                }else {
                    echo "<table cellpadding='0' cellspacing='0' border='0' class='nsmusertable1'><tr class='headercell'><td class='headercell'>Computer Name</td><td class='headercell'>MAC Address</td><td class='headercell'>&nbsp;</td></tr>\n";
                    $findmacs_arr = null;
                    while(($findmacs_arr = mysql_fetch_assoc($findusermacs_result))) {
                        echo "<tr><td>";
                        echo $findmacs_arr[comment];
                        echo "</td><td>";
                        echo $findmacs_arr[macaddr];
                        echo "</td><td>";
                        echo '<a onclick="return checkDeleteMac()" href="./bwlimit_user_managemacs.php?action=delete&amp;delete=';
                        echo   urlencode($findmacs_arr[macaddr]) . '">Delete</a>';
                        echo "</td></tr>";
                    }
                    echo "</tr></table>";
                }


                ?>
                <br/>
            <a href="./"> &lt;&lt; Back to NSM Main</a><br/><br/>
            
            <?php
            }
            ?>
           <?php echo make_nsm_footer(); ?>
        </div>
    </body>
</html>