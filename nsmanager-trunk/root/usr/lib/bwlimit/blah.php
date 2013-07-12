<?php
/* 
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

$sometime = mktime(10,0);
$dateinfo = getdate($sometime);
var_dump($dateinfo);



    $errormsg = "";
    //we are gonna use squid pam auth instead...
    $proc_descriptor = array(
        0 => array("pipe", "r"), //stdin is a pipe that the child will read from
        1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
        2 => array("pipe", "w") //stderr a pipe that will be written to
    );
    $cwd = "/tmp";
    $env = array();
    $process = proc_open("/usr/bin/wget -b http://www.yahoo.com/file.bin", $proc_descriptor, $pipes);
    if(is_resource($process)) {
        // $pipes now looks like this:
        // 0 => writeable handle connected to child stdin
        // 1 => readable handle connected to child stdout
        //fputs($pipes[0], "$username $pass\n");
        //fclose($pipes[0]);



        $line = "";
        $firstline = "";
        $count = 0;
        while(($line = fgets($pipes[1]))) {
            if($count == 0) {
                $firstline = $line;
            }
            $count++;
            echo $line;
        }

        $groups = array();
        preg_match('/pid (\d+)/', $firstline, &$groups);
        $pid = $groups[1];
        var_dump($groups);
        
        proc_close($process);


    }

?>
