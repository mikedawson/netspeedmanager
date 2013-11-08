<?php
require_once('simpletest/autorun.php');



class AllTests extends TestSuite {
    
    function AllTests() {
        $this->TestSuite('All tests');
        $this->addFile('testdatabaseconnect.php');
        $this->addFile('testusercreate.php');
        $this->addFile('test_create_iptables_rules.php');
        $this->addFile('testdhcpevents');
    }
}
?>