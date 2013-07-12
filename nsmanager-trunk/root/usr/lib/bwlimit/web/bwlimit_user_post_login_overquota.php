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
        <?php echo make_nsm_header(); ?>
        <h2>Sorry - Quota Exceeded!</h2>
        <p>
            Sorry but you have exceeded your usage quota.  You must wait for the next
            day until your usage is back within the limit or contact your system administrator.
        </p>
        <div id="messagearea">

        </div>
        <?php echo make_nsm_footer();?>
    </div>
</body>
</html>