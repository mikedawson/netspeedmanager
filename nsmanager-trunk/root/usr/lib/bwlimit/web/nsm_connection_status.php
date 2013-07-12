<?php
/* 
 * This will show the status of the connection as it is now ...
 */
require_once "bwlimit_user_functions.php";
require_once "../bwlimit-functions.php";

connectdb();

$connection_query_sql = "SELECT * FROM connection_status";
$connection_query_result = mysql_query($connection_query_sql);
$connection_query_arr = mysql_fetch_assoc($connection_query_result);

$gateway_status = $connection_query_arr['gateway_status'];
$internet_external_server_status = 0;
if($connection_query_arr['internet_ip'] == 1 && $connection_query_arr['internet_hostname'] == 1) {
    $internet_external_server_status = 1;
}


$css_classnames = array();
$css_classnames[0] = "status_problem";
$css_classnames[1] = "status_ok";

$status_text[0] = "Fail";
$status_text[1] = "OK";

?>



<table>
    <tr>
        <td class="testheader">Local Area Network</td>
        <td class="testheader">Connection to ISP Gateway</td>
        <td class="testheader">Connection from ISP to Internet</td>
    </tr>
    <tr>
        <td class="status_ok">
            OK
        </td>
        <td class="<?php echo $css_classnames[$gateway_status];?>">
            <?php echo $status_text[$gateway_status];?>
        </td>

        <td class="<?php echo $css_classnames[$internet_external_server_status];?>">
            <?php echo $status_text[$internet_external_server_status];?>
        </td>
    </tr>
</table>

<?php
if($gateway_status == 1 && $internet_external_server_status == 1) {
    ?>
    Your Internet Connection Appears OK!  If you are having problems accessing a website
    it more likely is a problem with that site than your local network or ISP.
    <?php
}else {
    ?>
    <p>Your Internet Connection appears to have a problem at the moment.  Your Local Area Network
    is OK.  Either the cable from the ISP to the Net Speed Manager system is not connected
    or there is a problem with your ISP / Internet Settings.  Please check them and if needed
    contact your ISP.  This is not a problem with Net Speed Manager.</p>

    <strong>Additional Diagnostic Information:</strong><br/>
    <b>Your Internet IP Setting:</b> <?php echo $connection_query_arr['externalip']; ?> <br/>
    <b>Your Internet Gateway Setting:</b> <?php echo $connection_query_arr['gatewayip']; ?><br/>
    <b>Internet DNS Name Resolution Status:</b>
    <?php echo $status_text[$connection_query_arr['internet_hostname']];?><br/>
    <b>Internet ping IP Test:</b>
    <?php echo $status_text[$connection_query_arr['internet_ip']];?><br/>

    <?php
}
?>

    <h2>Bandwidth provided by ISP:</h2>
    <table>
        <tr>
            <td><b>Download</b></td>
            <td><img src="downbar.png"/></td>
            <td>
                <?php echo file_get_contents("/usr/lib/bwlimit/web/downbar.txt");?>
            </td>
        </tr>

        <tr>
            <td><b>Upload</b></td>
            <td><img src="upbar.png"/></td>
            <td>
                <?php echo file_get_contents("/usr/lib/bwlimit/web/upbar.txt");?>
            </td>
        </tr>


    </table><br/>
    Average over 30 seconds.  In order to test the speed available from the Internet Service provider
    you must <b>start and continue a large download for at least one minute</b>
    
