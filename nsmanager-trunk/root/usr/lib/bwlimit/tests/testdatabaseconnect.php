<?php

/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */


require_once('simpletest/autorun.php');
require_once('../bwlimit-config.php');

class TestOfDatabaseConnect extends UnitTestCase {

    function setUp() {
        global $BWLIMIT_DBNAME;
        global $BWLIMIT_DBUSER;
        global $BWLIMIT_DBPASS;
        mysql_connect("localhost", $BWLIMIT_DBUSER, $BWLIMIT_DBPASS);
        mysql_select_db($BWLIMIT_DBNAME);
    }
    
    
    function tearDown() {
        
    }
    
    
    function testDatabaseCanConnect() {
        $bwstat = mysql_stat();
        $this->assertNotNull($bwstat);
    }
}

?>
