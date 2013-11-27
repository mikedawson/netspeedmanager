<?php

/*
 * Test creation of user - make sure that it gets created in user_details table
 */

require_once('simpletest/autorun.php');
require_once('../bwlimit-config.php');
require_once('../web/bwlimit_user_functions.php');
require_once('../bwlimit-autoadd-functions.php');
require_once('testconfig.php');

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
        
        echo "Test ldap user is $TESTLDAPUSER \n";
        $result = bwlimit_authenticate_ldap($TESTLDAPUSER, $TESTLDAPPASS);
        echo "In test result is $result\n";
        $this->assertEqual($result, 1);
        
        
        //bwlimit_add_user_from_ldap($TESTLDAPUSER);
        
        //test auto user creation
        $autouser_name = $TESTLDAPUSER . "automade";
        bwlimit_make_smeuser_account($autouser_name, "ldapautomade", "ldapautomade1", "auto@made.com", "ldap");
        
        //make sure that this account is in the system
        $this->assertTrue(is_dir("/home/e-smith/files/users/$autouser_name"));
        
        
        
    }
    
}