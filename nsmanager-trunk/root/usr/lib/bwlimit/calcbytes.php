#!/usr/bin/php

<?php
//we are gonna use squid pam auth instead...

    $fcontent = ioncube_read_file("/usr/lib/bwlimit/calcbytesen");
    
    $proc_descriptor = array(
        0 => array("pipe", "r"), //stdin is a pipe that the child will read from
        1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
        2 => array("pipe", "w") //stderr a pipe that will be written to
    );
    $cwd = "/tmp";
    $env = array();
    $process = proc_open("/bin/bash", $proc_descriptor, $pipes);
    if(is_resource($process)) {
        // $pipes now looks like this:
        // 0 => writeable handle connected to child stdin
        // 1 => readable handle connected to child stdout
        fputs($pipes[0], $fcontent);
        
        $line = null;
        while(($line = fgets($pipes[1])) != null) {
            echo $line;
        }
        
        //fclose($pipes[0]);

        $line = fgets($pipes[1]);
        
        proc_close($process);
        

    }
?>


