#!/usr/bin/php5

<?php
/* 
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

require_once "bwlimit-functions.php";


$line = null;
$char = null;

/*
while(($char = fgetc(STDIN)) != ''\n) {
    $line .= $char;
}
*/

$line = "MTWHF 09:00-11:30";

echo "Testing your timerange: " . $line . "\n";

$result = range_applies_to_time(time(), $line);

echo "Result is: $result\n";

connectdb();

load_time_ranges();

$mytime = 1262599200;

$rate = getrate($mytime);

echo "Rate = $rate\n";
$x = 0;


?>
