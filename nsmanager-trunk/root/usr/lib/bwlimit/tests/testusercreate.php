<?php

/*
 * Test creation of user - make sure that it gets created in user_details table
 */

require_once('simpletest/autorun.php');
require_once('../bwlimit-config.php');
require_once('../web/bwlimit_user_functions.php');

class TestOfUserCreation extends UnitTestCase {
    
    #should match with createtestuser.sh script
    public $testusername = "testuserabc";
    public $testpassword = "testuserpass";
    
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
        $mysql_find_user_stmt = "SELECT * FROM user_details WHERE username = '$this->testusername'";
        $mysql_find_user_result = mysql_query($mysql_find_user_stmt);
        $numrows_in_result = mysql_num_rows($mysql_find_user_result);
        echo "There are $numrows_in_result in result\n";
        $this->assertEqual($numrows_in_result, 1);
        
        $auth_result = bwlimit_authenticate($this->testusername, $this->testpassword);
        $this->assertTrue($auth_result);
    }
    
}



?>