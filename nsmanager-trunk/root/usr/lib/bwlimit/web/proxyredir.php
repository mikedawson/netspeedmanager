<?php
//This page is to generate redirects just as we want them
http_response_code(302);
header("Location: $_REQUEST[redir]");
?>
