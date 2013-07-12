#!/usr/bin/php
<?php
/* 
 * This is a squid redirector that will redirect to the access denied page if a user
 * exceeds their allocated quota, otherwise it will just return the address as before
 *
 * Note: This could be used to selectively deny certain items; e.g. ads, flash, etc.
 */
require_once "bwlimit-functions.php";

connectdb();

$debugfd = fopen("/var/www/SquidRedirector/redirdebug.txt", "a");

while($input = fgets(STDIN)) {
    $parts = explode(' ', $input);
    $user = $parts[2];
    
    $output = $parts[0] . "\n";
    if(strpos($parts[0], $BWLIMIT_OVERQUOTAPAGE)) {
        if(user_within_quota($user) == 0) {
            fwrite($debugfd, " User Over Quota! \n\n");
            $output = "302:" . $BWLIMIT_OVERQUOTAPAGE . "\n";
        }
    }
    
    echo $output;
}

?>