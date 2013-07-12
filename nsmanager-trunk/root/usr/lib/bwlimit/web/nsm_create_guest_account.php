<?php
/* 
 * This page is to be used by a user which is in the group for creating guest
 * users to create a new guest account with an expiration time
 *
 * It will check if the user is authenticated, has permission to create guest
 * accounts, and if they do it will create the account to be used.
 * 
 */

require_once "../bwlimit-functions.php";
require_once "bwlimit_user_functions.php";

connectdb();


$action = $_REQUEST['action'];

$action_error_msg = "";

if($action == 'create_guest') {
    //try and create the guest account

    $creator_username = $_REQUEST['creator_username'];
    $creator_password = $_REQUEST['creator_password'];

    $creator_auth_result = bwlimit_authenticate($creator_username, $creator_password);
    if($creator_auth_result == true) {
        $creator_can_make_acct_result = bwlimit_can_create_guest_account($creator_username);
        if($creator_can_make_acct_result == true) {
            //calculate when this account will expire
            $expire_delay =
                (intval($_REQUEST['expires_days']) * 86400)
                + (intval($_REQUEST['expires_hrs']) * 3600)
                + (intval($_REQUEST['expires_mins']) * 60);

            $expire_utime = time + $expire_delay;

            $create_guest_sql = "INSERT INTO user_details (username, daily_limit, "
                 . "weekly_limit, monthly_limit, is_guest_account, expires_utime, created_by, guest_pw) "
                 . " VALUES ('$_REQUEST[guest_username]', $_REQUEST[guest_daily_quota], "
                 . " $_REQUEST[guest_weekly_quota], $_REQUEST[guest_monthly_quota], "
                 . " 1, $expire_utime, '$creator_username', '$_REQUEST[guest_password1]')";
                 
            mysql_query($create_guest_sql);

        }else {
            $errormsg .= "Sorry, $creator_username is not authorized to create guest accounts";
        }
    }else {
        $errormsg .= "Sorry, Authentication for creator failed.";
    }




    


}

?>

<html>
    <head>
        <title>Net Speed Manager Toolbar</title>
        <link href='netspeedmanager_userstyle.css' type='text/css' rel='stylesheet'/>

    </head>

    <body>
        
        <div id="maincontainer">
            <?php echo make_nsm_header(); ?>
            
            <?php
            if($action && $action == 'create_guest') {
                if($errormsg == "") {
                    //no error, all good!
                    echo "Guest account $_REQUEST[guest_username] created OK!<br/>";
                    echo "You may now close this window";
                }else {
                    echo "<div class='nsmerror'><b>Error!</b><br/>$errormsg</div>";
                }
            }else {
                ?>

                <form method='post' action='nsm_create_guest_account.php'>
                    <input type='hidden' name='action' value='create_guest'/>

                    <p>
                        To create a guest account a user who is in the group
                        that is allowed to create guest accounts must fill
                        in the form below.
                    </p>

                    <table id='guest_table' cellpadding='0' cellspacing='0'>
                        <tr>
                            <td colspan='2' class='nsm_headercell'>Creator's Details</td>
                        </tr>

                        <tr>
                            <td>Creator's Username:</td>
                            <td><input name='creator_username' type='text' class='nsminputbox' size='12'/></td>
                        </tr>

                        <tr>
                            <td>Creator's Password:</td>
                            <td><input name='creator_password' type='password' class='nsminputbox' size='12'/></td>
                        </tr>

                        <tr>
                            <td colspan='2' class='nsm_headercell'>Guest Username/Password</td>
                        </tr>

                        <tr>
                            <td>Guest Username:</td>
                            <td><input name='guest_username' type='text' class='nsminputbox' size='12'/></td>
                        </tr>

                        <tr>
                            <td>Guest Password</td>
                            <td><input type='text' name='guest_password1' type='password' class='nsminputbox' size='12'/></td>
                        </tr>

                        <tr>
                            <td>Guest Password (confirm)</td>
                            <td><input type='text' name='guest_password2' type='password' class='nsminputbox' size='12'/></td>
                        </tr>

                        <tr>
                            <td>Expires After:</td>
                            <td>
                                <input type='text' name='expires_days' class='nsminputbox' size='2'/> days
                                <input type='text' name='expires_hrs' class='nsminputbox' size='2'/> hrs
                                <input type='text' name='expires_mins' class='nsminputbox' size='2'/> mins
                            </td>
                        </tr>

                        <tr>
                            <td colspan='2' class='nsm_headercell'>Guest Quota</td>
                        </tr>
                        <tr>
                            <td>Guest Daily Quota (Tokens)</td>
                            <td><input type='text' name='guest_daily_quota' class='nsminputbox' size='8'/></td>
                        </tr>

                        <tr>
                            <td>Guest Weekly Quota (Tokens)</td>
                            <td><input type='text' name='guest_weekly_quota' class='nsminputbox' size='8'/></td>
                        </tr>

                        <tr>
                            <td>Guest Monthly Quota (Tokens)</td>
                            <td><input type='text' name='guest_monthly_quota' class='nsminputbox' size='8'/></td>
                        </tr>
                     </table>

                     <input type='submit' value='Create Guest Account' class='nsmbutton'/>

                </form>
            <?php
            }
            ?>


            <?php echo make_nsm_footer();?>
        </div>
    </body>
</html>