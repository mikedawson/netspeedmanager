<?php

/*
 * Test creation of user - make sure that it gets created in user_details table
 */

require_once('simpletest/autorun.php');
require_once('../bwlimit-config.php');
require_once('../web/bwlimit_user_functions.php');

class TestOfUserCreation extends UnitTestCase {
    
    #should match with createtestuser.sh script
    public $createtestusername = "testuserabc_create";
    public $createtestpassword = "testuserpass";
    
    function setUp() {
        global $BWLIMIT_DBNAME;
        global $BWLIMIT_DBUSER;
        global $BWLIMIT_DBPASS;
        mysql_connect("localhost", $BWLIMIT_DBUSER, $BWLIMIT_DBPASS);
        mysql_select_db($BWLIMIT_DBNAME);
    }
    

    function testUserCreatedInDatabaseCanAuthenticate() {
        $mkuser_cmd="/usr/lib/bwlimit/tests/createtestuser.sh";
        $mkuser_cmd_result=`$mkuser_cmd`;
        $mysql_find_user_stmt = "SELECT * FROM user_details WHERE username = '$this->createtestusername'";
        $mysql_find_user_result = mysql_query($mysql_find_user_stmt);
        $numrows_in_result = mysql_num_rows($mysql_find_user_result);
        echo "There are $numrows_in_result in result\n";
        $this->assertEqual($numrows_in_result, 1);
        
        $auth_result = bwlimit_authenticate($this->createtestusername, $this->createtestpassword);
        $this->assertTrue($auth_result);
        
        //now make sure it will go away properly and get deleted cleanly
        $delete_user_cmd1 = "/sbin/e-smith/db accounts delete " . $this->createtestusername;
        $delete_user_res1 = `$delete_user_cmd1`;
        
        $delete_user_cmd2 = "/sbin/e-smith/signal-event user-delete " . $this->createtestusername;
        $delete_user_res2 = `$delete_user_cmd2`;
        
        $mysql_find_user_result2 = mysql_query($mysql_find_user_stmt);
        $numrows_in_result2 = mysql_num_rows($mysql_find_user_result2);
        $this->assertEqual($numrows_in_result2, 0);
    }
    
}



?>