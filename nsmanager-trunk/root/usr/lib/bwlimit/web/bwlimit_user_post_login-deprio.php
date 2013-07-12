<html>
<head>
    <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>
    <script type='text/javascript'>
        function moveOn() {
            <?php
            if($_REQUEST['redir']) {
                echo "var redirURL = '" . $_REQUEST['redir'] . "';\n";
            }else {
                echo "var redirURL = '';\n";
            }
            ?>
            var popWinURL = "/bwlimit/bwlimit_user_toolbar.php";
            var newWin = window.open(popWinURL, "netspeedmanager_toolbar",
                "width=150,height=600,toolbar=no,location=no");
            if(newWin) {
                newWin.blur();
                window.focus();
            }
            if(redirURL != "") {
                document.location.href = redirURL;
            }else  {
                document.getElementById('messagearea').innerHTML =
                    "Please type the address you wish to go to in the browser address bar";
            }

            return true;
        }
    </script>
</head>

<body>
    <div id="maincontainer">
        <?php 
	echo make_nsm_header(); 
	echo "<h2>Logging in... ";
        flush();

        //make sure that no stupid browsers cache stuff
        sleep(8);
        ?>

        Login OK!</h2>
	<p>But... because you have exceeded your quota you are deprioritized</p>
        <a href="#" onclick="return moveOn()">Click Here to Continue</a>&nbsp;
        <br/>&nbsp;
        &nbsp;
        <div id="messagearea">

        </div>
        <?php echo make_nsm_footer();?>
    </div>
</body>
</html>
