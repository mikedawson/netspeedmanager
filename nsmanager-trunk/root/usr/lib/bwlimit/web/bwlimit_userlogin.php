<?php
/* 
 * This will log the user in
 */

header("Cache-Control: no-cache");
require_once "bwlimit_user_functions.php";
require_once "../bwlimit-functions.php";
session_start();
connectdb();

$login_ok = check_login();

if($login_ok == TRUE) {
    include "bwlimit_user_post_login.php";
}else {

    $action  = $_REQUEST['action'];
    $redir = $_RESULT['redir'];
    $ipaddr_src = $_SERVER['REMOTE_ADDR'];

    connectdb();

    if($action == "login") {
        $username = mysql_escape_string($_REQUEST['username']);
        $pass = $_REQUEST['pass'];
        $remember = $_REQUEST['remember'];
        
        $result = bwlimit_authenticate($username, $pass);
        
        if($result == true) {
        
            if($remember) {
                //lookup the mac address
                $findmac_sql = "SELECT macaddr FROM macipcombos WHERE ipaddr = '$ipaddr_src'";
                $findmac_result = mysql_query($findmac_sql);
                if(mysql_num_rows($findmac_result) > 0) {
                    $findmac_arr = mysql_fetch_assoc($findmac_result);
                    $macaddr = $findmac_arr['macaddr'];
                    $saveitsql = "REPLACE INTO usersavedmacs (macaddr, username) "
                        . " VALUES ('$macaddr', '$username')";
                    mysql_query($saveitsql);
                }

            }
        
            if(user_within_quota($username) == 1) {
                bwlimit_user_ip_control($username, $ipaddr_src, true);
                include("bwlimit_user_post_login.php");
            }else {
                if($BWLIMIT_EXCEEDPOLICY == "cutoff") {
                        include("bwlimit_user_post_login_overquota.php");
                }else {
                    bwlimit_user_ip_control($username, $ipaddr_src, true);
                    include("bwlimit_user_post_login-deprio.php");
                }
            }
            ?>

            <?php
        }else {
            echo "Invalid username and password - please click back and try again";
        }

    }else {
        //show the form
        ?>
             <html>
                <head>
                    <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>
                </head>

                <body>
                    <div id="maincontainer">
                        <?php echo make_nsm_header(); ?>
                        <table border='0'>
                            <tr>
                                <td valign='top' width='300'>
                                    <p>Please login in order to activate net access...</p>
                                    <form action="/bwlimit/bwlimit_userlogin.php" method="post">
                                        <input type="hidden" name="action" value="login"/>
                                        <input type="hidden" name="redir" value="<?php echo $_REQUEST[redir];?>"/>
                                        <table>
                                            <tr>
                                                <td style="width: 140px;"><b>Username:</b></td>
                                                <td><input class='nsminputbox' type="text" name="username" size="12"/></td>
                                            </tr>

                                            <tr>
                                                <td><b>Password:</b></td>
                                                <td><input class='nsminputbox' type="password" name="pass" size="12"/></td>
                                            </tr>
                                            
                                            <?php
                                            
                                            //check and see if we know the mac address for this computer
                                            $user_remoteip = $_SERVER['REMOTE_ADDR'];
                                            $macaddr_check_sql = "SELECT macaddr FROM macipcombos WHERE ipaddr = '$user_remoteip' ";
                                                
                                            $macaddr_check_result = mysql_query($macaddr_check_sql);
                                            if(mysql_num_rows($macaddr_check_result) > 0) {
                                                //we know the mac - this was given out by our dhcp - o  ffer user the choice
                                                ?>    
                                            
                                                <tr>
                                                    <td colspan="2">
                                                        <input type="checkbox" value="remember" name="remember" id="remember" onchange="toggleRemember();"/>Automatically activate my account when this computer connects to the network
                                                    </td>
                                                </tr>
				

                                            <?php
                                            }
                                            ?>
                                            
                                        </table>
                                        
                                        <input type="submit" value="Login" class='nsmbutton'/>
                                        </form>
                                        
                                    </td>
                                    
                                    
                                    <td valign='top' width='500'>
                                        <?php include "bwlimit_userlogin_sideinclude.html"?>
                                    </td>
                                </tr>
                            </table>


                                
                        <?php echo make_nsm_footer();?>
                    </div>
                </body>
               </html>
        <?php
    }
}
?>
