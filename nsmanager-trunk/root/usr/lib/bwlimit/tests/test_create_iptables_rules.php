<?php

/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */


require_once('simpletest/autorun.php');
require_once('../bwlimit-config.php');
require_once "../bwlimit-functions.php";
require_once "testconfig.php";

class TestCreateIPTablesRules extends UnitTestCase {

    
    function setUp() {
        global $BWLIMIT_DBNAME;
        global $BWLIMIT_DBUSER;
        global $BWLIMIT_DBPASS;
        mysql_connect("localhost", $BWLIMIT_DBUSER, $BWLIMIT_DBPASS);
        mysql_select_db($BWLIMIT_DBNAME);
    }
    
    /*
     * Runs to check iptables rules are or are not present for PostroutingOutbound,
     * PreProxy, and TransProxy
     */
    function checkNatForIP($ipaddr, $isactive = True) {
        $ipaddr_esc = str_replace(".", "\\.", $ipaddr);
        $rules_to_find = "1";
        if($isactive == False) {
            $rules_to_find = "0";
        }
        
        //echo "Cmd = /sbin/iptables -t nat -L PostroutingOutbound -n | grep $ipaddr_esc  | wc -l \n";
        $postrouting_outbound_result = trim(`/sbin/iptables -t nat -L PostroutingOutbound -n | grep $ipaddr_esc  | wc -l`);
        $this->assertEqual($postrouting_outbound_result, $rules_to_find, "Expected postrouting outbound for $ipaddr - should be active $isactive to be $rules_to_find");
        $preproxy_outbound_result = trim(`/sbin/iptables -t nat -L PreProxy -n | grep $ipaddr_esc  | wc -l`);
        $this->assertEqual($preproxy_outbound_result, $rules_to_find, "Expected preproxy outbound for $ipaddr - should be active $isactive to be $rules_to_find");
        $transproxy_result = trim(`/sbin/iptables -t nat -L TransProxy -n | grep $ipaddr_esc  | wc -l`);
        $this->assertEqual($transproxy_result, $rules_to_find, "Expected transproxy outbound for $ipaddr - should be active $isactive to be $rules_to_find");
    }
    
    function checkSessionIsActiveInDb($username, $ipaddr) {
        $sql = "SELECT user_details.username AS username, "
                . "user_sessions.active_ip_addr AS active_ip_addr "
                . " FROM user_details LEFT JOIN user_sessions ON user_details.username = user_sessions.username "
                . " WHERE user_details.username = '$username' AND user_sessions.active_ip_addr = '$ipaddr' ";
        $sql_result = mysql_query($sql);
        $numrows = mysql_num_rows($sql_result);
        $this->assertEqual($numrows, 1, "check session is active for $ipaddr / $username not found");
     
    }
    
    /*
     * Check to make sure the correct htb-gen chains are in place
     * 
     * Checks to make sure two chains are in place : htb-gen.up-USERNAME and htb-gen.down-USERNAME 
     * 
     */
    function checkHtbIptablesRules($ipaddr, $username) {
        $ipaddr_esc = str_replace(".", "\\.", $ipaddr);
        
        
        $dirs = array("up", "down");
        foreach($dirs as $currentdir) {
            $username_chain_cmd = "/sbin/iptables -t mangle -L htb-gen.$currentdir-$username -n";
            $outputvar = "";
            $resultvar = "";
            //echo "check command = $username_chain_cmd \n";
            //run this command - if chain does not exist exit value will be 1
            exec($username_chain_cmd, &$outputvar, &$resultvar);
            ///echo "Result var = $resultvar for $username $currentdir \n";
            $this->assertEqual($resultvar, "0");
            
            $iptables_checkref_cmd = "/sbin/iptables -t mangle -L htb-gen.$currentdir "
                    . " -n | grep htb-gen.$currentdir-$username | grep  $ipaddr_esc  | wc -l";
            //echo "cmd = $iptables_checkref_cmd \n";
            $iptables_checkref_result = trim(`$iptables_checkref_cmd`);
            $this->assertEqual($iptables_checkref_result, "1");
        }
    }
    
    /**
     * 
     * @global type $TESTUSERNAME
     * @global type $TESTMOCKIPADDRESSES
     */
    function testLoginCreatesIPTablesRules() {
        global $TESTUSERNAME;
        global $TESTMOCKIPADDRESSES;
        
        //TODO: Make sure that this user is right now NOT online
        
        //Part 1: Test that all the mock ip addresses come up and online
        for($ipcount = 0; $ipcount < sizeof($TESTMOCKIPADDRESSES); $ipcount++) {
            bwlimit_user_ip_control($TESTUSERNAME, $TESTMOCKIPADDRESSES[$ipcount], true);
            $this->checkNatForIP($TESTMOCKIPADDRESSES[$ipcount]);
            $this->checkHtbIptablesRules($TESTMOCKIPADDRESSES[$ipcount], $TESTUSERNAME);
            $this->checkSessionIsActiveInDb($TESTUSERNAME, $TESTMOCKIPADDRESSES[$ipcount]);
        }
        
        //Part 2: Make sure with these devices they remain online
        for($ipcount = 0; $ipcount < sizeof($TESTMOCKIPADDRESSES); $ipcount++) {
            $this->checkNatForIP($TESTMOCKIPADDRESSES[$ipcount]);
            $this->checkHtbIptablesRules($TESTMOCKIPADDRESSES[$ipcount], $TESTUSERNAME);
        }
        
        //Part 3 - logout one and check the rest
        echo "test logout 1\n";
        bwlimit_user_ip_control($TESTUSERNAME, $TESTMOCKIPADDRESSES[0], false);
        $this->checkNatForIP($TESTMOCKIPADDRESSES[0], false);
        
        for($ipcount = 1; $ipcount < sizeof($TESTMOCKIPADDRESSES); $ipcount++) {
            $this->checkNatForIP($TESTMOCKIPADDRESSES[$ipcount]);
            $this->checkHtbIptablesRules($TESTMOCKIPADDRESSES[$ipcount], $TESTUSERNAME);
        }
        
        //Part 4 - log it all out
        echo "test logout 2\n";
        for($ipcount = 1; $ipcount < sizeof($TESTMOCKIPADDRESSES); $ipcount++) {
            bwlimit_user_ip_control($TESTUSERNAME, $TESTMOCKIPADDRESSES[$ipcount], false);
            $this->checkNatForIP($TESTMOCKIPADDRESSES[$ipcount], false);
        }
    }
    
}

?>