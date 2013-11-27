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
    var_dump($users_info);
    
}

?>
