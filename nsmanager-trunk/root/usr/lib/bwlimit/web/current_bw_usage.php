<?php
/*
 * This page shows the user a list of their scheduled transfers and then allows
 * them to cancel / pause / reschedule and resume them
 */
require_once "bwlimit_user_functions.php";
require_once "../bwlimit-functions.php";
require_once "bwlimit_user_config.php";

connectdb();

//Get Today
$get_today = "SELECT MAX(dayindex) FROM usage_logs";
$sett_today = mysql_query($get_today);
$set_today = mysql_result($sett_today, 0);


//Tabbed Browsing
$section = "";
$action = "";
if($_REQUEST['section']) {
    $section = $_REQUEST['section'];
}

if($_REQUEST['action']) {
    $action = $_REQUEST['action'];
}
?>

<html>
    <head>
        <link rel='stylesheet' href='netspeedmanager_userstyle.css' type='text/css'/>
    </head>
    <body>
        <div id="maincontainer">
            


                <table>
                    <tr>
                        <td colspan="4">
                            <h2>&nbsp;<br/>Bandwidth Usage</h2>

                        </td>
                    </tr>

                    <tr>
                        <td><a href="current_bw_usage.php&#63;section=daily">Daily</a></td>
                        <td><a href="current_bw_usage.php&#63;section=weekly">Weekly</a></td>
                        <td><a href="current_bw_usage.php&#63;section=monthly">Monthly</a></td>
                    </tr>

                    <tr>
                        <td colspan="4">
                            <?php
                                if ($section == ""){
                                    kbps_current();
                                }
                                elseif ($section == "daily"){
                                    get_info(1, 'Daily Usage (MB)');
                                }
                                elseif ($section == "weekly"){
                                    get_info(7, 'Weekly Usage (MB)');
                                }
                                elseif ($section == "monthly"){
                                    get_info(30, 'Monthly Usage (MB)');
                                }
                                else{
                                    echo "Tab Error";
                                }

                            //End of Tabbed Browsing
                            ?>
                        </td>
                    </tr>
                </table>



                <?php
                //Used in development not deleted because of cowardice
                function make_report_table($days_to_go_back, $title)
                {

                    //Get Today
                    //Returns the integer of the current day from MySQL
                    $get_today = "SELECT MAX(dayindex) FROM usage_logs";
                    $sett_today = mysql_query($get_today);
                    $set_today = mysql_result($sett_today, 0);

                    
                    $set_from = $set_today - $days_to_go_back;
                    $my_graph;

                    $find_user_sql = "SELECT user, SUM(usage_bytes) AS sum_usage_bytes FROM usage_logs WHERE dayindex >= '".$set_from."' AND dayindex <= '".$set_today."' GROUP BY user ORDER BY sum_usage_bytes DESC";
                    
                    $find_user_result = mysql_query($find_user_sql);
                    $find_user_arr = null;
                    while(($find_user_arr = mysql_fetch_assoc($find_user_result))) {
                        if ($find_user_arr[user]== '' || $find_user_arr[user]=='-')continue;
                            $find_user_arr[sum_usage_bytes] = round(($find_user_arr[sum_usage_bytes]/(1024*1024)),2);
                            $my_graph["$find_user_arr[user]"] = $find_user_arr[sum_usage_bytes];
                    }

                            
                     graph($my_graph, 2);
                     table($my_graph, $title);

                }

                //The first Tab results, creates graph and table itself
                function kbps_current()
                {
                    $my_array;
                    $find_user_sql = "select * from user_details where current_kbps > 0 ORDER BY current_kbps DESC";
                    $find_user_result = mysql_query($find_user_sql);
                    $find_user_arr = null;
                    while(($find_user_arr = mysql_fetch_assoc($find_user_result)))
                    {
                        //Ignore results with username '' or '-' as we dont care about those
                        if($find_user_arr[username] == '' || $find_user_arr[username == '-'])continue;
                        //Put the relevant results into a friendly array
                        $my_array["$find_user_arr[username]"] = "$find_user_arr[current_kbps]";
                    }

                    //Get the total usage of Kbps
                    $total_kbps = "SELECT SUM(current_kbps) as total_kbps FROM user_details";
                    $get_total_kbps = mysql_query($total_kbps);
                    $total = mysql_result($get_total_kbps, 0);

                    //Generate the kbps Graph
                    $width = 600;
                    $height = count($my_array)*20;
                    $array_max = max($my_array);
                    //Graph is displayed using layered Divs
                    //As container relative, internal divs be absolute compared to this.
                    echo "<div id=graph_container style=\"position: relative; width:".$width."px ; height: ".$height."; z-index:".$z_index."\">";
                    echo "\n";
                    $row = 0;
                    foreach($my_array as $key => $value){
                        //Calculate width of div and set my_width to this
                        $my_width = ($width / $array_max)*$value;
                        //Create the div
                        echo "<div id=row".$value." style=\"position:absolute;top:".$row."; background-color:#CCC; width:".$my_width."px;\">";
                        $row = $row + 20;
                        //echo the username + kbps
                        echo $key ."($value)";
                        //end the bar div
                        echo "</div>";
                        echo "\n";
                    }
                    unset($value);
                    //end the graph_container div
                    echo "\t</div>\n";

                    //Generate the kbps Table
                    //$total = 0;
                    echo "<table class='report_table'>\n";
                    echo "<tr>\n";
                    echo "\t<th>User</th>";
                    echo "<th>Current kbps</th>";
                    echo "</tr>\n";
                    foreach ($my_array as $key => $value)
                    {
                        echo "<tr>";
                        echo "<td>$key</td>";
                        echo "<td>$value</td>";
                        echo "<tr>\n";
                        //$total = $total + $value;
                    }
                    echo "<tr class='report_table_total'>";
                    echo "<td>Total</td>";
                    echo "<td align=right>$total</td>\n";
                    echo "</table>\n\n";

                }
                //Gets the result based on number of days passed to it
                //Title is used on Table Creation
                function get_info($days, $title)
                {
                    $mysql_today = "SELECT MAX(dayindex) FROM usage_logs";
                    $get_today = mysql_query($mysql_today);
                    $today = mysql_result($get_today, 0);

                    $set_from = $today - ($days - 1);
                    $mysql_query = "SELECT user, SUM(usage_bytes) AS total_bytes, SUM(saved_bytes) AS total_saved FROM usage_logs WHERE dayindex >= '".$set_from."' AND dayindex <='".$today."' GROUP BY user ORDER BY total_bytes DESC";


                    $my_array = array();
                    
                    $get_info_result = mysql_query($mysql_query);
                    $get_info_arr = null;
                    while(($get_info_arr = mysql_fetch_assoc($get_info_result)))
                    {
                        //Skip username = '' or '-'
                        if ($get_info_arr[user]== '' || $get_info_arr[user]=='-')continue;
                        $user = $get_info_arr[user];
                        //raw bytes
                        $total_bytes = $get_info_arr[total_bytes];
                        // bytes to MB
                        $total_bytes = round($total_bytes/(1024*1024),2);
                        $total_saved = $get_info_arr[total_saved];
                        $total_saved = round($total_saved/(1024*1024),2);

                        //An array of arrays
                        // The key is username
                        //The sub array keys are total_bytes and total saved
                        $my_array[$user] = array("total_bytes" =>$total_bytes, "total_saved" => $total_saved);
                        
                    }
                    graph($my_array);
                    table($my_array, $title);
                }


                function graph($an_array)
                {
                      
                    $width = 600;
                    $height_of_bar = 20;
                    $count = count($an_array);
                    $height = $height_of_bar * $count;
                    $max_number = 0;
                    foreach($an_array as $key => $value)
                    {

                        //Find the largest total bytes
                        $current_num = $value["total_bytes"];
                        if($current_num > $max_number) {
                            $max_number = $current_num;
                        }

                    }
                    $array_max = $max_number;
                    echo "\n\t";
                    echo "<div id=\"graph_container\" style=\"position: relative; width:".$width."px ; height: ".$height."px;\">\n\n";
                    
                    $barcount = 0;
                    $row = 0;

                    //Notes of the foreach
                    //Key refers to the username
                    //value is the array total_bytes & bytes_saved
                    foreach($an_array as $key => $value)
                    {
                        //Layered Divs
                        $my_width = ($width / $array_max)*$value["total_bytes"];
                        //Used (always the longest) at the bottom
                        echo "<div class='bytes' style=\"position:absolute;top:".$row."; width:".$my_width."px\">&nbsp;</div>\n";
                        $my_width = ($width / $array_max)*$value["total_saved"];
                        //Saved in the middle
                        echo "<div class='saved' style=\"position:absolute;top:".$row."; width:".$my_width."px;\">&nbsp;</div>\n";
                        //The info on the top
                        echo "<div class='title' style=\"position:absolute;top:".$row."; background-color:transparent;\">$key - ".$value["total_bytes"]."</div>\n";

                        $row = $row + $height_of_bar;
                    }
                    
                    echo "\n\t\t";
                    echo "</div>";
                }

                //Makes a table based on the array created in get_info
                function table($an_array, $title)
                {
                     echo "<table class='report_table'>\n";
                     echo "<tr>";
                     echo "<th>Users</th>";
                     echo "<th>$title</th>";
                     echo "<th>MB saved</th>";
                     echo "</tr>";

                     $total = 0;
                     $total_saved = 0;
                     foreach($an_array as $key => $value){

                         echo "<tr>\n";
                         echo "<td>$key</td>\n";
                         echo "<td>".$value["total_bytes"]."</td>\n";
                         echo "<td>".$value["total_saved"]."</td>\n";
                         echo "</tr>\n";
                         $total = $total+$value["total_bytes"];
                         $total_saved = $total_saved + $value["total_saved"];
                    }
                    echo "<tr class='report_table_total'>\n<td>Total</td>";
                    echo "<td align='right'>$total</td>";
                    echo "<td align='right'>$total_saved</td>";
                    echo "</tr>\n";
                    echo "</table>";
                }
            echo make_nsm_footer();
            ?>
        </div>
    </body>
