#!/usr/bin/php

<?php

require_once "bwlimit-functions.php";

connectdb();

bwlimit_delete_user($argv[1]);

?>
