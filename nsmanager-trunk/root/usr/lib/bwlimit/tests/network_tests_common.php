<?php

Class NetworkTestsCommon {

    /*
     * Runs to check iptables rules are or are not present for PostroutingOutbound,
     * PreProxy, and TransProxy
     */
    function checkNatForIP($unitTestObj, $ipaddr, $isactive = True) {
        $ipaddr_esc = str_replace(".", "\\.", $ipaddr);
        $rules_to_find = "1";
        if($isactive == False) {
            $rules_to_find = "0";
        }
        
        //echo "Cmd = /sbin/iptables -t nat -L PostroutingOutbound -n | grep $ipaddr_esc  | wc -l \n";
        $postrouting_outbound_result = trim(`/sbin/iptables -t nat -L PostroutingOutbound -n | grep $ipaddr_esc  | wc -l`);
        $unitTestObj->assertEqual($postrouting_outbound_result, $rules_to_find, "Expected postrouting outbound for $ipaddr - should be active $isactive to be $rules_to_find");
        $preproxy_outbound_result = trim(`/sbin/iptables -t nat -L PreProxy -n | grep $ipaddr_esc  | wc -l`);
        $unitTestObj->assertEqual($preproxy_outbound_result, $rules_to_find, "Expected preproxy outbound for $ipaddr - should be active $isactive to be $rules_to_find");
        $transproxy_result = trim(`/sbin/iptables -t nat -L TransProxy -n | grep $ipaddr_esc  | wc -l`);
        $unitTestObj->assertEqual($transproxy_result, $rules_to_find, "Expected transproxy outbound for $ipaddr - should be active $isactive to be $rules_to_find");
    }
    
    function checkSessionIsActiveInDb($unitTestObj, $username, $ipaddr) {
        $sql = "SELECT user_details.username AS username, "
                . "user_sessions.active_ip_addr AS active_ip_addr "
                . " FROM user_details LEFT JOIN user_sessions ON user_details.username = user_sessions.username "
                . " WHERE user_details.username = '$username' AND user_sessions.active_ip_addr = '$ipaddr' ";
        $sql_result = mysql_query($sql);
        $numrows = mysql_num_rows($sql_result);
        $unitTestObj->assertEqual($numrows, 1, "check session is active for $ipaddr / $username not found");
     
    }
    
    /*
     * Check to make sure the correct htb-gen chains are in place
     * 
     * Checks to make sure two chains are in place : htb-gen.up-USERNAME and htb-gen.down-USERNAME 
     * 
     */
    function checkHtbIptablesRules($unitTestObj, $ipaddr, $username) {
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
            $unitTestObj->assertEqual($resultvar, "0");
            
            $iptables_checkref_cmd = "/sbin/iptables -t mangle -L htb-gen.$currentdir "
                    . " -n | grep htb-gen.$currentdir-$username | grep  $ipaddr_esc  | wc -l";
            //echo "cmd = $iptables_checkref_cmd \n";
            $iptables_checkref_result = trim(`$iptables_checkref_cmd`);
            $unitTestObj->assertEqual($iptables_checkref_result, "1");
        }
    }
}
?>
