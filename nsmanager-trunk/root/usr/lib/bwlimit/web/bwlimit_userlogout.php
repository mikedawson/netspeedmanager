<?php
require_once "bwlimit_user_functions.php";
require_once "../bwlimit-functions.php";

connectdb();
session_start();

//load any applicable logins...
check_login();

if($_SESSION['user']) {
    $username = $_SESSION['user'];
    $ipaddr = $_SERVER[REMOTE_ADDR];
    setcookie("bwlimits[un]", "", time() - 3600*24);
    setcookie("bwlimits[pw]", "", time() - 3600*24);
    unset($_SESSION['user']);
    bwlimit_user_ip_control($username, $ipaddr, false);
    
    //because they have actually logged out - delete any applicable mac combos
    $delete_mac_sql = "DELETE FROM usersavedmacs WHERE username = '$username'";
    mysql_query($delete_mac_sql);
}
?>

<html>
<head>
    <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>
</head>

<body>
    <div id="maincontainer">
        <?php echo make_nsm_header(); ?>
        <h2>Logout</h2>
        <p>You have now been logged out - net access deactivated - you can
            <a href="bwlimit_userlogin.php">Login Again</a> if needed
        </p>

        <?php echo make_nsm_footer(); ?>

    </div>
</body>
</html>
