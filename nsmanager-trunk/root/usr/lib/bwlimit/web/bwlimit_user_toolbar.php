<?php
/* 
 * Shows the user his / her bandwidth based on $_SESSION[user] which is set
 * by logging in
 *
 * Also considers the display mode for the user
 *
 */

require_once "../bwlimit-functions.php";
connectdb();

require_once "bwlimit_user_functions.php";


check_login();

$css_colors = array("green", "yellow", "red");

//check what the thresholds are

$username = $_SESSION['user'];

$bwinfo = null;
if($username) {
    $bwinfo = get_bwinfo($username);
}
?>

<html>
    <head>
        <title>Net Speed Manager Toolbar</title>
        <link href='netspeedmanager_userstyle.css' type='text/css' rel='stylesheet'/>
        <meta http-equiv='refresh' content='300; ./bwlimit_user_toolbar.php'/>
        <script type="text/javascript">
            
          
            
        </script>
        
        <style type='text/css'>
            #container_upload {
            width : 120px;
            height: 120px;
            margin: 8px auto;

          }
          
          
          #container_download {
            width : 120px;
            height: 160px;
            margin: 8px auto;

          }
          
          .resultok {
            color: green;
            font-weight: bold;
          }
          
          .resultfail {
            color: red;
            font-weight: bold;
          }
          
        </style>
    </head>

    <body>
        <div id="maincontainer">
        <div id='toolbox_container'>
            <img src="nsm64.png" alt='Net Speed Manager'/><br/>
            <?php
            if($username) {
                echo "<span class='usernamelabel'>Hello $username! <br/>Your Quota Status is...<br/></span>";

                $timeperiod_names = array('daily', 'weekly','monthly');

                foreach($timeperiod_names as $timeperiod_name) {
                    echo "<span class='toolbox_periodlabel'>$timeperiod_name :</span><br/>";
                    $periodquota = intval($bwinfo[$timeperiod_name]['quota'] / (1024*1024));
                    echo "<span class='toolbox_quotalabel'>&nbsp;&nbsp;&nbsp; Quota $periodquota"
                        . " Tokens</span>";
                    $this_status = $bwinfo[$timeperiod_name]['status'];
                    $this_status_color = $css_colors[$this_status];

                    echo "<div class='toolbar_usagebox' style='background-color: $this_status_color'>&nbsp;</div>";
                }
                ?>

                
                <?php
                $client_ip = $_SERVER['REMOTE_ADDR'];
                
                echo "<div class='tools_header'>Tools</div>";
                ?>
                Your Speed (kbps): 
                
                <div id='container_download'></div>
                
                <table border='0'>
                    <tr>
                        <td>&nbsp;</td><td>You</td><td>All Users</td>
                    </tr>
                    <tr>
                        <td>Down</td><td align='center'><span id='downmy'>&nbsp;</span></td><td align='center'><span id='downall'>&nbsp;</span></td>
                    </tr>
                    <tr>
                        <td>Up</td><td align='center'><span id='upmy'>&nbsp;</span></td><td align='center'><span id='upall'>&nbsp;</span></td>
                    </tr>
                </table>
                    
                <small><b>Internet: &nbsp;</b><span id='constatus'>&nbsp;</span></small><br/>
                <small><b>Connection: &nbsp;</b><span id='connote'>&nbsp;</span></small>
                <script type="text/javascript" src="flotr2.min.js"></script>
    
                <script type='text/javascript' src='nsm_graph_functions.js'></script>
                
                <script type='text/javascript'>
                    mode = MODE_SINGLEUSER;
                    xmlReqExtraParams = "client_username=<?php echo $username;?>&coninfo=y";
                    makexmlhttpreq();
                </script>
                
                
                
                <?php
                
                
                
                //echo "<a href='nsm_user_scheduledxfermgr.php' target='_blank' class='tool_button_link'>Schedule Transfer</a>";
                //echo "<a href='#' class='tool_button_link'>Time &amp; Token Rates</a>";
                //echo "<a href='current_bw_usage.php' target='_blank' class='tool_button_link'>Current Usage Report</a>";
                echo "<a href='bwlimit_userlogout.php' target='_blank' class='tool_button_link'>Logout</a>";
            }else {
                echo "Sorry session expired";
            }

            ?>

            

            <div class='copyright_notice'>
                Copyright &copy; 2009 PAIWASTOON.
            </div>
        </div>
        </div>
    </body>
</html>




