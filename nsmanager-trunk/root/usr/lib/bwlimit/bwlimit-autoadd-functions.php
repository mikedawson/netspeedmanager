<?php

require_once "bwlimit-functions.php";


function bwlimit_check_autoaddusers() {
    
}

function bwlimit_add_user_from_ldap($username) {
    global $LDAP_FIRSTNAMEFIELD, $LDAP_SECONDNAMEFIELD, $LDAP_MAILFIELD;
    
    $ds = bwlimit_ldap_connect();
    bwlimit_ldap_bind($ds);
    
    //search for user
    $attrs = array($LDAP_FIRSTNAMEFIELD, $LDAP_SECONDNAMEFIELD, $LDAP_MAILFIELD);
    $user_info = bwlimit_ldap_getuserinfo($ds, $username, $attrs);
    
    $firstname = $user_info[0][strtolower($LDAP_FIRSTNAMEFIELD)][0];
    $secondname = $user_info[0][strtolower($LDAP_SECONDNAMEFIELD)][0];
    $mailaddr = $user_info[0][strtolower($LDAP_MAILFIELD)][0];
    
    bwlimit_make_smeuser_account($username, $firstname, $secondname, $mailaddr, "ldap");
}

function bwlimit_make_smeuser_account($username, $firstname, $lastname, $mailaddr, $authsrc) {
    $mkusr_cmd1 = "/sbin/e-smith/db accounts set \"$username\" user FirstName \"$firstname\" "
                . " LastName \"$lastname\" BWLimitAuthSource $authsrc";
    $result1 = `$mkusr_cmd1`;
    
    echo "mkusr cmd 1 $mkusr_cmd1 \n";
    
    $mkusr_cmd2 = "/sbin/e-smith/signal-event user-create $username";
    $result2 = `$mkusr_cmd2`;
    
    echo "mkusr cmd2 = $mkusr_cmd2 \n";
}

?>
