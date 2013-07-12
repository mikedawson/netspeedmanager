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

//do any update action here


//used to make links for actions as required
$basename = "./nsm_guest_mgr.php";

$guest_list_sql = "SELECT username, daily_limit, weekly_limit, monthly_limit FROM " .
    " user_details where is_guest_account = 1";

$guest_list_result = mysql_query($guest_list_sql);
?>

<html>
    <head>
        <title>Net Speed Manager Toolbar</title>
        <link href='netspeedmanager_userstyle.css' type='text/css' rel='stylesheet'/>


        <script type='text/javascript'>
            var scriptBaseHref = '<?php echo $basename;?>';
        </script>

    </head>

    <body>

        <div id="maincontainer">
            <?php echo make_nsm_header(); ?>
            <h2>Guest User Manager</h2>
            <table>
                <tr>
                    <th>Username</th>
                    <th>Expires</th>
                    <th>Daily Limit</th>
                    <th>Weekly Limit</th>
                    <th>Monthly Limit</th>
                    <th>Created By</th>

                    <!-- Space for update button -->
                </tr>

                <?php
                $guest_list_arr = null;
                while(($guest_list_arr = mysql_fetch_assoc($guest_list_result)) != null) {
                    echo "<tr>";
                    echo "<td>$guest_list_arr[username]</td>";
                    echo "<td>";
                    //TODO
                    $expire_utime = $guest_list_arr['expires_utime'];
                    
                    echo "</td>";



                    echo "</td></tr>";
                }
                ?>


            </table>
        </div>
    </body>

</html>
