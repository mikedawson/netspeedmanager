<?php

/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */


require_once('simpletest/autorun.php');
require_once('../bwlimit-config.php');
require_once('network_tests_common.php');
require_once("testconfig.php");

class TestOfDHCPEvents extends UnitTestCase {

    function setUp() {
        global $BWLIMIT_DBNAME;
        global $BWLIMIT_DBUSER;
        global $BWLIMIT_DBPASS;
        
        global $TESTDHCPMACADDR;
        global $TESTUSERNAME;
        global $TESTDHCPIPADDR;
        
        
        
        mysql_connect("localhost", $BWLIMIT_DBUSER, $BWLIMIT_DBPASS);
        mysql_select_db($BWLIMIT_DBNAME);
        
        //now make an entry for it as associated with a user
        $sql_insert_mac="INSERT INTO usersavedmacs (macaddr, username, comment) "
                . " VALUES ('$TESTDHCPMACADDR', '$TESTUSERNAME', '')";
        mysql_query($sql_insert_mac);
        
        
    }
    
    function tearDown() {
        global $TESTUSERNAME;
        $sql_delete_mac= "DELETE FROM usersavedmacs WHERE username = '$TESTUSERNAME'";
        mysql_query($sql_delete_mac);
    }
    
    function testDHCPEvents() {
        //trigger the event
        global $TESTDHCPMACADDR;
        global $TESTUSERNAME;
        global $TESTDHCPIPADDR;
        
        
        $cmd_commit = "/usr/lib/bwlimit/nsm-dhcp-event-handler.php commit $TESTDHCPIPADDR $TESTDHCPMACADDR";
        echo "Commit command = $cmd_commit\n";
        
        $cmdout  = `$cmd_commit`;
        
        //should be connected now
        $networkTestObj = new NetworkTestsCommon;
        $networkTestObj->checkNatForIP($this, $TESTDHCPIPADDR);
        $networkTestObj->checkHtbIptablesRules($this, $TESTDHCPIPADDR, $TESTUSERNAME);
        
        //run it again - make usre we don't get any strange stuff for that...
        $cmd_commit = "/usr/lib/bwlimit/nsm-dhcp-event-handler.php commit $TESTDHCPIPADDR $TESTDHCPMACADDR";
        $cmdout  = `$cmd_commit`;
        $networkTestObj = new NetworkTestsCommon;
        $networkTestObj->checkNatForIP($this, $TESTDHCPIPADDR);
        $networkTestObj->checkHtbIptablesRules($this, $TESTDHCPIPADDR, $TESTUSERNAME);
        
        
        //now disconnect
        $cmd_expiry = "/usr/lib/bwlimit/nsm-dhcp-event-handler.php expiry $TESTDHCPIPADDR $TESTDHCPMACADDR";
        $cmdout  = `$cmd_expiry`;
        
        $networkTestObj->checkNatForIP($this, $TESTDHCPIPADDR, false);
    }
    
}