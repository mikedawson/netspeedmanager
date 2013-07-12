
var xmlHttpReqStart;

var xmlHttpReqCheck;

var xmlHttpReqResult;

var speedcheckWaitDuration;

var speedcheckCountTime;

var speedcheckCountDuration;

var speedcheckEndTime;

var countDownVal = -2;

var countDownElementId;

var countdownRunning = false;

function start_test_request() {
    xmlHttpReqStart = new XMLHttpRequest();
    var parameters="action=start&pass=" + document.getElementById("speedcheck_passwordfield").value;
    xmlHttpReqStart.onreadystatechange = start_test_reply;
    xmlHttpReqStart.open("POST", "/bwlimit/bwlimit_speedcheck_control.php", true);
    xmlHttpReqStart.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
    xmlHttpReqStart.send(parameters);
    document.getElementById("speedcheck_passwordfield").value = "";
}

function start_test_reply() {
    if(xmlHttpReqStart.readyState == 4 && xmlHttpReqStart.status == 200) {
        var xmlDoc = xmlHttpReqStart.responseXML.documentElement;
        var testElementList = xmlDoc.getElementsByTagName("test");
        if(testElementList.length >= 1) {
            var testElement = testElementList[0];
            
            speedcheckStartTime = parseInt(testElement.getAttribute("starttime"));
            speedcheckWaitDuration = parseInt(testElement.getAttribute("waittime"));
            
            //calibrate this such that it will show the speed coming through the pipe on the graph
            speedcheckCountTime = speedcheckStartTime + speedcheckWaitDuration + dataTimeInterval;
            speedcheckCountDuration = parseInt(testElement.getAttribute("counttime"))
            speedcheckEndTime = speedcheckCountTime + speedcheckCountDuration;
            
            checkSpeedCtrl = 1;
            
            start_countdown("speedcheck_wait_time", speedcheckWaitDuration + (dataTimeInterval*2));
            
            $("#speedcheck_password").hide();
            $("#speedcheck_wait").show();
        }else {
            var authElement = xmlDoc.getElementsByTagName("auth")[0];
            if(authElement.getAttribute("result") == "0") {
                alert("Invalid Password");
            }else {
                alert("Another speed test is already ongoing ... please wait");
            }
        }
    }
}

function update_speed_test() {
    if(lastTimeKnown > speedcheckEndTime) {
        $("#speedcheck_count").hide();
        $("#speedcheck_wait").hide();
        $("#speedcheck_password").show();
        $("#speedcheck_popout").hide();
        checkSpeedCtrl = 0;
        
        $("#speedresult_line").effect("pulsate");
        
        //todo - show the new result
    }else if(lastTimeKnown > speedcheckCountTime) {
        $("#speedcheck_wait").hide();
        $("#speedcheck_count").show();
    }
}

function start_countdown(elementId, startVal) {
    if(countdownRunning == false) {
        countDownElementId = elementId;
        countDownVal = startVal;
        updateCountdown();
    }    
}

function updateCountdown() {
    document.getElementById(countDownElementId).innerHTML = new String(countDownVal);
    countDownVal -= 1;
    if(countDownVal > 0) {
        setTimeout("updateCountdown()", 1000);
    }else {
        countdownRunning = false;
    }
}

function bwcheckStart() {
    $("#speedcheck_popout").show();
}   


