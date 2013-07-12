
        var xmlhttp;
        
        var CLIENT_TIME = 0;
        var CLIENT_DOWNKBPS = 1;
        var CLIENT_UPKBPS = 2;
        
        var newMasterClientData = [];
        
        var newMasterGroupData = [];
        
        var newMasterTotalData = [];
        
        var clientDataUpload;
        
        var clientDataDownload;
        
        var TIMESTAMP = 0;
        var BYTES = 1;
    	var KBPS = 2;
        
        //the time in seconds over which the graph lasts
        var graphMaxTime = 600;
        
        //the nominal frequency at which data is updated (in seconds)
        var dataTimeInterval = 10;
        
        var maxPts = 60;
        
        var lastTimeKnown = -1;
        
        var xmlReqExtraParams = "";
        
        var MODE_ALL = 0;
        
        var MODE_SINGLEUSER = 1;
        
        var mode = MODE_ALL;
        
        //base graph options
        var options = null;
        
        //associative array in the form of 'username' => 'groupname'
        var usernamesToGroups = [];
        
        //xml request used to get user groups file (generated by SME server)
        var graphxmlhttp;
        
        var GRAPHTYPE_USER = 0;
        var GRAPHTYPE_GROUP = 1;
        
        var currentGraphType = GRAPHTYPE_USER;
        var currentGraphGroupFilter = null;
        
        //this is here to see if we need to check a speed test after getting graph results..
        var checkSpeedCtrl = 0;
        
        
        function doUserGroupXMLRequest() {
            graphxmlhttp = new XMLHttpRequest();
            graphxmlhttp.onreadystatechange = readUserGroupMap;
            graphxmlhttp.open("GET", "usergroups.xml");
            graphxmlhttp.send();
        }
        
        function readUserGroupMap() {
            if(graphxmlhttp.readyState == 4 && graphxmlhttp.status == 200) {
                //let's read this
                var rootEl = graphxmlhttp.responseXML.documentElement;
                var usernameEls = rootEl.getElementsByTagName("user");
                for(var i = 0; i < usernameEls.length; i++) {
                    var currentUsername = usernameEls[i].getAttribute("id");
                    var currentGroup = usernameEls[i].getAttribute("group");
                    usernamesToGroups[currentUsername] = currentGroup;
                }
                
                //now that we know what the groups are make the request...
                makexmlhttpreq();
            }
        }
        
        
        /*
        File a user speed into it's group
        */
        function updateGroupMasterData(username, time, kbpsDown, kbpsUp) {
            var groupName = usernamesToGroups[username];
            if(!newMasterGroupData[groupName]) {
                newMasterGroupData[groupName] = [];
            }
            
            //find the correct place in the group data by time, or create a new point
            var ptIndex = -1;
            var numPtsInGroup = newMasterGroupData[groupName].length;
            if(numPtsInGroup == 0 || 
                (numPtsInGroup > 0 && newMasterGroupData[groupName][numPtsInGroup-1][CLIENT_TIME] < time)) {
                
                //we just throw this on the end as a new point
                newMasterGroupData[groupName][numPtsInGroup] = [time, kbpsDown, kbpsUp];
            }else if(numPtsInGroup > 0 && newMasterGroupData[groupName][0][CLIENT_TIME] > time) {
                //we need to throw this in right at the start
                var newArr = [time, kbpsDown, kbpsUp];
                newMasterGroupData[groupName].unshift(newArr);
            }else {
                //search backwards and find the right place to put this
                var didInsert = false;
                for (var i = numPtsInGroup - 1; i >= 0; i--) {
                    //find if it matches
                    if(newMasterGroupData[groupName][i][CLIENT_TIME] == time) {
                        newMasterGroupData[groupName][i][CLIENT_DOWNKBPS] += kbpsDown;
                        newMasterGroupData[groupName][i][CLIENT_UPKBPS] += kbpsUp;
                        didInsert = true;
                        break;
                    }else if(newMasterGroupData[groupName][i][CLIENT_TIME] < time) {
                        //we need to insert just after this one (i+1)
                        var newArr = [time, kbpsDown, kbpsUp];
                        newMasterGroupData[groupName].splice(i, 0, newArr);
                        didInsert = true;
                        break;
                    }
                }
            }
        }
    
        function makexmlhttpreq() {
            xmlhttp = new XMLHttpRequest();
            xmlhttp.onreadystatechange = updategraphs;
            var params = "";
            
            if(lastTimeKnown == -1) {
                params = "q=600";
            }else {
                params = "timesince=" + lastTimeKnown;
            }    
            
            xmlhttp.open("GET","graphdata.php?" + params + "&" + xmlReqExtraParams,true);
            xmlhttp.send();
            setTimeout("makexmlhttpreq()", dataTimeInterval * 1000);
        }
        
        
        function updateMasterTotalData(docElement) {
            var totalElement = docElement.getElementsByTagName("totals")[0];
            var usageEls = totalElement.getElementsByTagName("usage");
            
            for(var i = 0; i < usageEls.length; i++) {
                var ptUtime = parseInt(usageEls[i].getAttribute("time"));
                newMasterTotalData[newMasterTotalData.length] = [
                    ptUtime, parseInt(usageEls[i].getAttribute("kbps_down")),
                    parseInt(usageEls[i].getAttribute("kbps_up"))
                    ];
            }
            
            var myLastTime = 0;
            var oldestTimeOK = lastTimeKnown - graphMaxTime;
            while(myLastTime < oldestTimeOK && newMasterTotalData.length > 0) {
                myLastTime = newMasterTotalData[0][0];
                if(newMasterTotalData[0][0] < oldestTimeOK) {
                    newMasterTotalData.shift();
                }
            }
            
        }
        
        function updateClientTable() {
            for(username in newMasterClientData) {
                var numDataPts = newMasterClientData[username].length;
                var dlSpeed = newMasterClientData[username][numDataPts-1][CLIENT_DOWNKBPS];
                var ulSpeed = newMasterClientData[username][numDataPts-1][CLIENT_UPKBPS];
                
                var titleCellEl = document.getElementById("titlecelluser_"+username);
                if(titleCellEl) {
                    //continue...
                    document.getElementById("dlspeeduser_" + username).innerHTML = dlSpeed;
                    document.getElementById("ulspeeduser_" + username).innerHTML = ulSpeed;
                }
            }
        
        }
        
        function valInArray(arr, val) {
            for(var i = 0; i < arr.length; i++) {
                if(arr[i] == val) {
                    return true;
                }
            }
            
            return false;
        }
        
        /**
        When the user selects to view users, allow them to show only a specific group of users.
        */
        function filterClientsByGroupSelect() {
            var groupSelected = document.forms['userGroupForm'].elements['userGroupSelect'].value;
            if(groupSelected == ":ALLUSERS:") {
                currentGraphGroupFilter = null;
                $("INPUT.usergroupitem").prop("checked", true);
                $(".usergroupitem").css("display", "");
            }else {
                //hide others
                currentGraphGroupFilter = groupSelected;
                $("INPUT.usergroupitem").prop("checked", false);
                $(".usergroupitem").css("display", "none");
                $(".usergroup_" + groupSelected).css("display", "");
                $("INPUT.usergroup_" + groupSelected).prop("checked", true);
            }
            
            drawMainGraphs();
        }
        
        /*
        This will make a table of the client name, download and upload speeds.
        */
        function genCurrentClientTable() {
            var srcArr = null;
            if(currentGraphType == GRAPHTYPE_USER) {
                srcArr = newMasterClientData;
            }else {
                srcArr = newMasterGroupData;
            }
            
            
            var htmlStr = "<form name='userGroupForm'>";
            
            if(currentGraphType ==GRAPHTYPE_USER) {
                //show a dropdown list of groups to inspect
                var groupsShown = [];
                htmlStr += "Filter by Group: <select id='userGroupSelect' onchange='filterClientsByGroupSelect()'>";
                htmlStr += "<option value=':ALLUSERS:'>All Users</option>";
                for(username in srcArr) {
                    var groupName = usernamesToGroups[username];
                    if(!valInArray(groupsShown, groupName)) {
                        htmlStr += "<option value='" + groupName + "'>" + groupName + "</option>";
                        groupsShown[groupsShown.length] = groupName;
                    }
                }
                htmlStr += "</select>";
            }
            
            htmlStr += "<table id='clientSpeedTable'><tr><th>Username</th><th>Down (kbps)</th><th>Up (kbps)</th></tr>";
            for(username in srcArr) {
                var numDataPts = srcArr[username].length;
                var dlSpeed = srcArr[username][numDataPts-1][CLIENT_DOWNKBPS];
                var ulSpeed = srcArr[username][numDataPts-1][CLIENT_UPKBPS];
                
                var grpClassStr = "";
                if(currentGraphType == GRAPHTYPE_USER) {
                    grpClassStr = " class='usergroupitem usergroup_" + usernamesToGroups[username] + "' ";
                }
                
                var checkboxStr = "<input " + grpClassStr + "type='checkbox' checked='checked' onchange='drawMainGraphs()' id='usercheckbox_" + username +"'/>";
                htmlStr += "<tr" + grpClassStr + "><td id='titlecelluser_" + username + "'>" + checkboxStr + " " + username + "</td><td id='dlspeeduser_" + username + "'>" + dlSpeed + "</td><td id='ulspeeduser_" + username +"'>" + ulSpeed + "</td></tr>";
            }
            htmlStr += "</table>";
            htmlStr += "</form>";
            
            return htmlStr;
        }
        
        
        
        
        /*
        Filter the users that we actually want to see
        */
        function filterDataPts(arr) {
            for(var i = 0; i < arr.length; i++) {
                var username = arr[i]['label'];
                var checkboxItem = document.getElementById("usercheckbox_" + username);
                if(checkboxItem && checkboxItem.checked == false) {
                    arr.splice(i, 1);
                    i -= 1;
                }
                /*
                else if(currentGraphType == GRAPHTYPE_USER && currentGraphGroupFilter != null) {
                    if(usernamesToGroups[username]  != currentGraphGroupFilter) {
                        arr.splice(i, 1);
                        i -= 1;
                    }
                }*/
            }
            
            return arr;
        }
        
        
        /*
        Update the main master client data array that feeds the graph
        */
        function updateMasterClientData(docElement) {
            var clients = docElement.getElementsByTagName("client");
                        
            //because we might have to skip graph points that only have one data point
            for(var i = 0; i < clients.length; i++) {
                //check if we have a reference for this
                var username = clients[i].getAttribute("username");
                if(!newMasterClientData[username]) {
                    newMasterClientData[username] = [];
                }
                
            
                var dataPts = [];
                
                var usageEls = clients[i].getElementsByTagName("usage");
                for(var j = 0; j < usageEls.length; j++) {
                    var numPts = newMasterClientData[username].length;
                    var ptUtime = parseInt(usageEls[j].getAttribute("time"));
                    var kbpsDown = parseInt(usageEls[j].getAttribute("kbps_down"));
                    var kbpsUp = parseInt(usageEls[j].getAttribute("kbps_up"));
                    newMasterClientData[username][numPts] = [ptUtime, kbpsDown, kbpsUp];
                    updateGroupMasterData(username, ptUtime, kbpsDown, kbpsUp);
                    
                    if(ptUtime > lastTimeKnown) {
                        lastTimeKnown = ptUtime;
                    }
                }
                
            }
            
            //Go through and remove old entries
            trimArr(newMasterClientData);

        }
        
        /*
        Trims the master data arrays to remove data older than 
        the last time
        */
        function trimArr(srcArr) {
            var oldestTimeOK = lastTimeKnown - graphMaxTime;
            for(var username in srcArr) {
                var myLastTime = 0;
                while(myLastTime < oldestTimeOK && srcArr[username].length > 0) {
                    myLastTime = srcArr[username][0][0];
                    if(srcArr[username][0][0] < oldestTimeOK) {
                        srcArr[username].shift();
                    }
                }
            
            }
        }
        
        
        
        function newTotalToDataPts(attrIndex, labelName) {
            
            var dataPts = [];
            for(var i = 0; i < newMasterTotalData.length; i++) {
                dataPts[i] = [ newMasterTotalData[i][0], newMasterTotalData[i][attrIndex] ] ;
            }
            
            return [ { label : labelName, data :  dataPts  } ];
        }
        
        
        
        function newGraphToDataPts(attrIndex, srcArray) {
            var retVal = [];
            
            //because we might have to skip graph points that only have one data point
            for(var username in srcArray) {
                if(srcArray.hasOwnProperty(username)) {
                    var dataPts = [];
                    
                    for(var i = 0; i < srcArray[username].length; i++) {
                        dataPts[i] = [srcArray[username][i][0], srcArray[username][i][attrIndex] ];
                    }
                    
                    retVal[retVal.length] = { data : dataPts, label: username };
                }
            }
    
            return retVal;
        }
        
        
        function newGraphToToolbarDataPts() {
            var upDataPts = [];
            var downDataPts = [];
            for(var username in newMasterClientData) {
                if(newMasterClientData.hasOwnProperty(username)) {
                    //found it
                    for(var i = 0; i < newMasterClientData[username].length; i++) {
                        upDataPts[upDataPts.length] = [ newMasterClientData[username][i][0], newMasterClientData[username][i][CLIENT_UPKBPS] ];
                        downDataPts[downDataPts.length] = [ newMasterClientData[username][i][0], newMasterClientData[username][i][CLIENT_DOWNKBPS] ];
                    }
                }
            }
            
            return [
                { label : "down", data : downDataPts },
                { label : "up", data : upDataPts }
            ];
        }
        
        var timeformatter = function(x){
            var x = parseInt(x);
            var myDate = new Date(x*1000);
            var mins = myDate.getMinutes();
            if(mins < 10) {
                mins = "0" + mins;
            }
            var string = myDate.getHours() + ":" + mins;
            result = string;
            return string;

            //return x;
        }
        
        function toggleGraphType() {
            var boxEl = document.getElementById("showGraphByUser");
            
            if(boxEl.checked == true) {
                currentGraphGroupFilter = null;
                currentGraphType = GRAPHTYPE_USER;
            }else {
                currentGraphType = GRAPHTYPE_GROUP;
            }
            drawMainGraphs();
            document.getElementById("userTable").innerHTML = genCurrentClientTable();
        }
        
        function drawMainGraphs() {
            var arrToUse = null;
            if(currentGraphType == GRAPHTYPE_USER) {
                arrToUse = newMasterClientData;
            }else {
                arrToUse = newMasterGroupData;
            }
        
            var downDataPts = newGraphToDataPts(CLIENT_DOWNKBPS, arrToUse);
            downDataPts = filterDataPts(downDataPts);
            
            var upDataPts = newGraphToDataPts(CLIENT_UPKBPS, arrToUse);
            upDataPts = filterDataPts(upDataPts);
            
            
            Flotr.draw(document.getElementById("container_download"), downDataPts, options);
            
            Flotr.draw(document.getElementById("container_upload"), upDataPts, options);
            
            if(document.getElementById("container_totaldown")) {
                var downloadTotalData = newTotalToDataPts(CLIENT_DOWNKBPS, "Download");
                Flotr.draw(document.getElementById("container_totaldown"), downloadTotalData, options);
            }
            
            if(document.getElementById("container_totalup")) {
                var uploadTotalData = newTotalToDataPts(CLIENT_UPKBPS, "Upload");
                Flotr.draw(document.getElementById("container_totalup"), uploadTotalData, options);
            }
        }

        
        function updategraphs() {
            if (xmlhttp.readyState==4 && xmlhttp.status==200) {
                var docElement = xmlhttp.responseXML.documentElement;

                updateMasterClientData(docElement);
                
                updateMasterTotalData(docElement);
                
                trimArr(newMasterGroupData);
                
                options = {
                    HtmlText : false,
                    xaxis : {
	                mode: "time",
                        labelsAngle : 90,
                        title: "Time",
                        tickFormatter : timeformatter
                    } ,
                    yaxis : {
	                    title : "Speed (kbps)",
                        titleAngle : 90,
                        min: 0
                   }
                };
                
                if(mode != MODE_SINGLEUSER) {
                    updateStatus(docElement);
            
                    drawMainGraphs();
                    
                    if(document.getElementById("clientSpeedTable")) {
                        updateClientTable();
                    }else {
                        document.getElementById("userTable").innerHTML = genCurrentClientTable();
                    }
                    
                    
                }else {
                    //we are in the toolbar
                    var clientData = newGraphToToolbarDataPts();
                    Flotr.draw(document.getElementById("container_download"), clientData, options);
                    
                    var clientDataDown = clientData[0]['data'];
                    var clientDataUp = clientData[1]['data'];
                    
                    var dlspeedTotal = Math.round(docElement.getAttribute("dlspeed"));
                    var ulspeedTotal = Math.round(docElement.getAttribute("ulspeed"));
                                        
                    var dlspeedMy = Math.round(clientDataDown[clientDataDown.length-1][1]);
                    var ulspeedMy = Math.round(clientDataUp[clientDataUp.length-1][1]);
                    
                    document.getElementById('downmy').innerHTML = dlspeedMy;
                    document.getElementById('upmy').innerHTML = ulspeedMy;
                    
                    document.getElementById('downall').innerHTML = Math.max(dlspeedMy, dlspeedTotal);
                    document.getElementById('upall').innerHTML = Math.max(ulspeedMy, ulspeedTotal);
                    
                    updateConnectionStatus(docElement.getAttribute("constatus"));
                }
            }
            
            if(checkSpeedCtrl == 1) {
                update_speed_test();
            }
        }
        
        function updateConnectionStatus(status) {
            status = parseInt(status);
            var statusHTML = "";
            if(status == 1) {
                statusHTML = "<span class='resultok'>UP</span>";
            }else {
                statusHTML = "<span class='resultfail'>DOWN</span>";
            }
            
            document.getElementById("constatus").innerHTML = statusHTML;
        }
        
	function updateConNote(note) {
		document.getElementById("connote").innerHTML = note;
	}              
	
	
