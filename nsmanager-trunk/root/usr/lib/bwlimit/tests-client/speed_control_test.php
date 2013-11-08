<?php
/*
 * This unit test will check against the account configured in clientconfig.php
 * 
 * The client this is running on should be signed onto that account
 * 
 * Will check download speeds and upload speeds are in between rate and ceiling for
 * upload and download
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
        
        $upload_filename = "nsm_randupload" . time();
        $cmd_make_upload_file = "dd if=/dev/urandom of=$upload_filename bs=1M count=30";
        $mk_upload_result = `$cmd_make_upload_file`;
        
        $bytecountcmd_rx = 'cat /proc/net/dev | grep ' . $TESTINTERFACE 
                . " | cut -d ':' -f 2 | awk '" . '{print $1}' . "'";
        $bytecountcmd_tx = 'cat /proc/net/dev | grep ' . $TESTINTERFACE 
                . " | cut -d ':' -f 2 | awk '" . '{print $9}' . "'";
                
        
        $cmd_start_download = "wget -b $TESTURL?time=" . time();
        
        
        $pid_text = `$cmd_start_download`;
        $start_upload_result=`./forkupload.sh $TESTURL $upload_filename`;
        
        
        
        echo "download+upload started...\n";
        //wait two seconds for it to get moving
        sleep(2);
        $bytecount_rx_start = intval(`$bytecountcmd_rx`);
        $bytecount_tx_start = intval(`$bytecountcmd_tx`);
        
        $time_start = time();
        
        //wait for 30 seconds to check on speed
        sleep(30);
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
        
    }
    
}
?>
