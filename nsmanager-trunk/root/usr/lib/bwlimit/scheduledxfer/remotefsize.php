<?php
echo remote_filesize("http://www.yahoo.com");

function remote_filesize($url)
{
   ob_start();
   $ch = curl_init($url);
   curl_setopt($ch, CURLOPT_HEADER, 1);
   curl_setopt($ch, CURLOPT_NOBODY, 1);

   $ok = curl_exec($ch);
   curl_close($ch);
   $head = ob_get_contents();
   ob_end_clean();

   $regex = '/Content-Length:\s([0-9].+?)\s/';
   $count = preg_match($regex, $head, $matches);

   return isset($matches[1]) ? intval($matches[1]) : -1;
}
?>