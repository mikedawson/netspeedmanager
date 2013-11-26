<?php

/*
 * Test creation of user - make sure that it gets created in user_details table
 */

require_once('simpletest/autorun.php');
require_once('../bwlimit-config.php');
require_once('../web/bwlimit_user_functions.php');


class TestOfLDAPAuth extends UnitTestCase {

    function setUp() {
        global $BWLIMIT_DBNAME;
        global $BWLIMIT_DBUSER;
        global $BWLIMIT_DBPASS;
        mysql_connect("localhost", $BWLIMIT_DBUSER, $BWLIMIT_DBPASS);
        mysql_select_db($BWLIMIT_DBNAME);
    }
    
    
    function testLDAPCanAuthenticate() {
        global $TESTLDAPUSER, $TESTLDAPPASS;
        
        $result = bwlimit_authenticate_ldap($TESTLDAPUSER, $TESTLDAPPASS);
        
    }
    
}