<?php

/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */


require_once('simpletest/autorun.php');
require_once('../bwlimit-config.php');
require_once "../bwlimit-functions.php";
require_once "testconfig.php";
require_once "network_tests_common.php";

class TestCreateIPTablesRules extends UnitTestCase {

    
    function setUp() {
        global $BWLIMIT_DBNAME;
        global $BWLIMIT_DBUSER;
        global $BWLIMIT_DBPASS;
        mysql_connect("localhost", $BWLIMIT_DBUSER, $BWLIMIT_DBPASS);
        mysql_select_db($BWLIMIT_DBNAME);
    }
    
    
    
    /**
     * 
     * @global type $TESTUSERNAME
     * @global type $TESTMOCKIPADDRESSES
     */
    function testLoginCreatesIPTablesRules() {
        global $TESTUSERNAME;
        global $TESTMOCKIPADDRESSES;
        
        $networkTestObj = new NetworkTestsCommon;
        
        //TODO: Make sure that this user is right now NOT online
        
        //Part 1: Test that all the mock ip addresses come up and online
        for($ipcount = 0; $ipcount < sizeof($TESTMOCKIPADDRESSES); $ipcount++) {
            bwlimit_user_ip_control($TESTUSERNAME, $TESTMOCKIPADDRESSES[$ipcount], true);
            $networkTestObj->checkNatForIP($this, $TESTMOCKIPADDRESSES[$ipcount]);
            $networkTestObj->checkHtbIptablesRules($this, $TESTMOCKIPADDRESSES[$ipcount], $TESTUSERNAME);
            $networkTestObj->checkSessionIsActiveInDb($this, $TESTUSERNAME, $TESTMOCKIPADDRESSES[$ipcount]);
        }
        
        //Part 2: Make sure with these devices they remain online
        for($ipcount = 0; $ipcount < sizeof($TESTMOCKIPADDRESSES); $ipcount++) {
            $networkTestObj->checkNatForIP($this, $TESTMOCKIPADDRESSES[$ipcount]);
            $networkTestObj->checkHtbIptablesRules($this, $TESTMOCKIPADDRESSES[$ipcount], $TESTUSERNAME);
        }
        
        //Part 3 - logout one and check the rest
        echo "test logout 1\n";
        bwlimit_user_ip_control($TESTUSERNAME, $TESTMOCKIPADDRESSES[0], false);
        $networkTestObj->checkNatForIP($this, $TESTMOCKIPADDRESSES[0], false);
        
        for($ipcount = 1; $ipcount < sizeof($TESTMOCKIPADDRESSES); $ipcount++) {
            $networkTestObj->checkNatForIP($this, $TESTMOCKIPADDRESSES[$ipcount]);
            $networkTestObj->checkHtbIptablesRules($this, $TESTMOCKIPADDRESSES[$ipcount], $TESTUSERNAME);
        }
        
        //Part 4 - log it all out
        echo "test logout 2\n";
        for($ipcount = 1; $ipcount < sizeof($TESTMOCKIPADDRESSES); $ipcount++) {
            bwlimit_user_ip_control($TESTUSERNAME, $TESTMOCKIPADDRESSES[$ipcount], false);
            $networkTestObj->checkNatForIP($this, $TESTMOCKIPADDRESSES[$ipcount], false);
        }
    }
    
}

?>