<?php

require "/usr/lib/bwlimit/bwlimit_grouplist.php";

function bwlimit_generate_password($length = 7) {
    $retval = "";
    $chars="abcdefghijklmnopqrstuvwxyz123456789";
    for($i = 0; $i < $length; $i++) {
        $retval .= $chars[(rand() % strlen($chars))];
    }
    
    return $retval;
}

function makestrcode($timestamp) {
    return date("Ymd", $timestamp);
}


function autoreset_generate_passwords($fromtime, $numdays){
    global $autoreset_users;
    
    //make sure we dont have multiple entries hanging around
    mysql_query("DELETE FROM autoreset_users");
    
    $table_html = "";
    $generated_stamp = date("d/M/Y G:i");
    
    for($day = 0; $day < $numdays; $day++) {
        
        $utime = $fromtime + ($day * 60 * 60 * 24);
        $strdatecode = makestrcode($utime);
        
        $fordate = date("d/M/Y", $utime);
        $table_html .= "<h1>Usernames/Passwords for " . $fordate . "</h1>";
        $table_html .= "<table class='passtable'>";
        for($i = 0; $i < count($autoreset_users); $i++) {
            $user = $autoreset_users[$i];
            $pass = bwlimit_generate_password();
            $applyday = makestrcode($utime);
            $sql_query = "INSERT INTO autoreset_users(username, password, applyday, actioned) VALUES "
                . " ('$user', '$pass', '$applyday', 0)";
            mysql_query($sql_query);
            
            $table_html .= "<tr><td valign='top' class='passusercell'>Username: $user <br/> Password: $pass<br/><br/>";
            $table_html .= "<span class='ticketsmall'>Valid $fordate (Generated $generated_stamp)</span>";
            $table_html .= "</td>";
            
            
            $table_html .= "<td class='passmessagecell' valign='top' >";
            if(file_exists("ticket_include.html")) {
                $table_html .= file_get_contents("ticket_include.html");
            }
            $table_html .= "</td></tr>";

        }
        
        $table_html .= "</table><hr/>";
    }    
    
    return $table_html;
}

?>
