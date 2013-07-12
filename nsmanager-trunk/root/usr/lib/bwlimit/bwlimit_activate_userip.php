#!/usr/bin/php5/php

<?php
/*
 * This will activate an ip and user address combo
 *
 */

require_once "bwlimit-functions.php";

//go through the arguments
$ipaddr = "";
$username = "";

function print_usage() {
    echo "usage: bwlimit_activate_userip -u <username> -a <ipaddr>\n";
    exit (1);
}



for($i = 1; $i < $argc; $i++) {
    if($argv[$i] == "-u") {
        $username = $argv[$i+1];
    }else if($argv[$i] == "-a") {
        $ipaddr = $argv[$i+1];
    }
}

if(!$username || !$ipaddr) {
    print_usage();
}

connectdb();
bwlimit_user_ip_control($username, $ipaddr, true);

?>