<?php
/*
 * This unit test will check against the account configured in clientconfig.php
 * 
 * The client this is running on should be signed onto that account
 * 
 * Will check download speeds and upload speeds are in between rate and ceiling for
 * upload and download.
 * 
 * Will also make sure that the ipactivity is updated for the account so that
 * the cron job picks up this address as active and does not disconnect it
 * 
 */

require_once "clientconfig.php";
require_once('simpletest/autorun.php');

class Test_SpeedControl extends UnitTestCase {
    
    function setUp() {
        
    }
    
    /*
     * Do the actual test
     */
    function testSpeedControl() {
        global $TESTINTERFACE;
        global $TESTURL;
        global $TESTCLIENT_DOWN_RATE, $TESTCLIENT_DOWN_CEIL, $TESTCLIENT_SPEEDS;
        global $TESTCLIENT_UP_RATE, $TESTCLIENT_UP_CEIL;
        global $TESTSERVER;
        
        $wait_time = 30;
        
        $upload_filename = "nsm_randupload" . time();
        $cmd_make_upload_file = "dd if=/dev/urandom of=$upload_filename bs=1M count=30";
        $mk_upload_result = `$cmd_make_upload_file`;
        
        $bytecountcmd_rx = 'cat /proc/net/dev | grep ' . $TESTINTERFACE 
                . " | cut -d ':' -f 2 | awk '" . '{print $1}' . "'";
        $bytecountcmd_tx = 'cat /proc/net/dev | grep ' . $TESTINTERFACE 
                . " | cut -d ':' -f 2 | awk '" . '{print $9}' . "'";
                
        
        $cmd_start_download = "wget -b $TESTURL?time=" . time();
        
        //check the last ip activity time before we did the test
        $last_ipactivity_url = "http://$TESTSERVER/bwlimit/bwlimit_testinfo_provider.php" 
                . "?action=getiplastactivitytime";
        $last_ipactivity_stream = fopen($last_ipactivity_url, "r");
        $last_ipactivity_xmlstr = stream_get_contents($last_ipactivity_stream);
        fclose($last_ipactivity_stream);
        $last_ipactivity_xmlobj = simplexml_load_string($last_ipactivity_xmlstr);
        $last_ipactivity_start = intval($last_ipactivity_xmlobj->result->time);
        
        
        $pid_text = `$cmd_start_download`;
        $start_upload_result=`./forkupload.sh $TESTURL $upload_filename`;
        
        
        
        echo "download+upload started...\n";
        //wait two seconds for it to get moving
        sleep(2);
        $bytecount_rx_start = intval(`$bytecountcmd_rx`);
        $bytecount_tx_start = intval(`$bytecountcmd_tx`);
        
        $time_start = time();
        
        //wait for 30 seconds to check on speed
        sleep($wait_time);
        $bytecount_rx_end = intval(`$bytecountcmd_rx`);
        $bytecount_tx_end = intval(`$bytecountcmd_tx`);
        
        $time_end = time();
        $kill_cmd_down = 'killall wget';
        $kill_cmd_result = `$kill_cmd_down`;
        
        $bytes_xfer_rx =  $bytecount_rx_end - $bytecount_rx_start;
        $bytes_xfer_tx = $bytecount_tx_end - $bytecount_tx_start;
        
        $kbps_down = (($bytes_xfer_rx*8)/1024)/($time_end - $time_start);
        $kbps_up = (($bytes_xfer_tx*8)/1024)/($time_end - $time_start);
        
        echo "bytes_xfer_rx = $bytes_xfer_rx / down speed = $kbps_down \n";
        echo "bytes_xfer_tx = $bytes_xfer_tx / up speed = $kbps_up\n";
        
        $this->assertEqual($bytes_xfer_rx > 0, True);
        $this->assertEqual($bytes_xfer_tx > 0, True);
        
        $this->assertEqual($kbps_down > $TESTCLIENT_SPEEDS[$TESTCLIENT_DOWN_RATE], True);
        $this->assertEqual($kbps_down  < $TESTCLIENT_SPEEDS[$TESTCLIENT_DOWN_CEIL], True);
        
        $this->assertEqual($kbps_up > $TESTCLIENT_SPEEDS[$TESTCLIENT_UP_RATE], True);
        $this->assertEqual($kbps_up < $TESTCLIENT_SPEEDS[$TESTCLIENT_UP_CEIL], True);
        
        //now check that the server recorded this correctly
        $suminfo_url = "http://" . $TESTSERVER . "/bwlimit/bwlimit_testinfo_provider.php" 
                . "?action=sumbwcalcentries&start_utime=$time_start&end_utime=$time_end";
        $stream = fopen($suminfo_url, "r");
        $stream_content_str = stream_get_contents($stream);
        //echo $stream_content_str;
        $xmlobjs = simplexml_load_string($stream_content_str);
        $server_xfer_count = intval($xmlobjs->sum->bytetotal);
        
        $total_xfer = ($bytes_xfer_rx + $bytes_xfer_tx);
        $diff = abs($server_xfer_count - $total_xfer);
        $numcounts = $wait_time / 10;
        $diffok = (1/$numcounts)*$total_xfer;
        $variance_fraction = $diff/$total_xfer;
        echo "Server counts $server_xfer_count we count $total_xfer Variance = $variance_fraction\n";
        
        $this->assertEqual($variance_fraction < (1/$numcounts), True);
        
        //now check that the activity was seen
        $last_ipactivity_url_end = "http://$TESTSERVER/bwlimit/bwlimit_testinfo_provider.php" 
                . "?action=updatelastactivitytime";
        $last_ipactivity_stream_end = fopen($last_ipactivity_url_end, "r");
        $last_ipactivity_xmlstr_end = stream_get_contents($last_ipactivity_stream_end);
        fclose($last_ipactivity_stream_end);
        $last_ipactivity_xmlobj_end = simplexml_load_string($last_ipactivity_xmlstr_end);
        $last_ipactivity_end = intval($last_ipactivity_xmlobj_end->result->time);
        
        echo "last ip activity at the end: $last_ipactivity_end vs  $last_ipactivity_start \n";
        $this->assertEqual($last_ipactivity_end >= ($last_ipactivity_start + $wait_time), True);
        
        
        
    }
    
}
?>
