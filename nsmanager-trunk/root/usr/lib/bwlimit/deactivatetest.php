#!/usr/bin/php5/php

<?php
/* 
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

require_once "bwlimit-functions.php";
connectdb();
bwlimit_user_ip_control("mike", "192.168.1.248", false, true);
?>
