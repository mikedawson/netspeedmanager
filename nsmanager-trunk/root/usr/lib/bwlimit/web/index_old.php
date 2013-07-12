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



?>

<html>
    <head>
        <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>
        <title>Net Speed Manager</title>
        <script type="text/javascript">
            function showToolbar() {
                var popWinURL = "/bwlimit/bwlimit_user_toolbar.php";
                var newWin = window.open(popWinURL, "netspeedmanager_toolbar",
                    "width=150,height=600,toolbar=no,location=no");
            }

            function showIntro() {
                var popWinURL = "/bwlimit/intro/index.html";
                var newWin = window.open(popWinURL, "netspeedmanager_intro",
                    "width=1000,height=۷00,toolbar=no,location=no");
            }
        </script>
    </head>

    <body>
        <div id="maincontainer">
            <?php echo make_nsm_header(); ?>

            <h2>Welcome to Net Speed Manager</h2>

            <table width="950">
                <tr>
                    <td width="125"><img src="icons/toolbar-icon.png" onclick="showToolbar()"/></td>
                    <td valign="top" width="350">
                        <h3>Open My Net Speed Manager Toolbar</h3>
                        <p>Use this to see your bandwith usage status, schedule downloads, logout etc.</p>
                    </td>

                    <td width="125"><img src="icons/icon-question.png" onclick="showIntro()"/></td>
                    <td valign="top" width="350">
                        <h3>Net Speed Manager - Quick Introduction</h3>
                        <p>A brief step by step guide that explains the key features of Net Speed Manager</p>
                    </td>

                    
                </tr>
                <tr>
                    <td>&nbsp;</td>
                </tr>

                <tr>
                    <td width="125"><a href="/bwlimit/user-manual/index.html"><img border="0" src="icons/user-man-icon.png"/></a></td>
                    <td valign="top" width="350">
                        <h3>User Manual</h3>
                        <p>Complete manual for users of Net Speed Manager.</p>
                    </td>

                    <td width="125"><a href="/bwlimit/admin-manual/index.html"><img border="0" src="icons/admin-man-icon.png"/></a></td>
                    <td valign="top" width="350">
                        <h3>Administrator's Manual</h3>
                        <p>Complete manual for administrator's of Net Speed Manager</p>
                    </td>


                </tr>
                <tr><td>&nbsp;</td></tr>

                <tr>
                    <td width="125"><a href="/bwlimit/current_bw_usage.php"><img border="0" src="icons/status-icon.png"/></a></td>
                    <td valign="top" width="350">
                        <h3>Current Status</h3>
                        <p>Current connection status / bandwidth usage reports.</p>
                    </td>

                    <td width="125"><a href="/server-manager"><img src="icons/icon-controlpanel.png" border="0  "/></a></td>
                    <td valign="top" width="350">
                        <h3>Control Panel</h3>
                        <p>Enter the Administrator control panel</p>
                    </td>


                </tr>
                <tr><td>&nbsp;</td></tr>

            </table>
        </div>
    </body>

</html>