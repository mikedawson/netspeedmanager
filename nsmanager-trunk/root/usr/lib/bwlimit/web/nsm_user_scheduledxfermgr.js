/* 
 * Exists to manage the scheduled download manager function
 * 
 */

// the request used for ajax
var xmlHttpRequest = null;

// an associative array of the downloads in the form of requestid -> object
var requests = new Array();

var updateTimer;

//amount of time to wait after updating table to refresh
var updateWait = 5000;

function requestupdate() {
    if(xmlHttpRequest == null) {
        xmlHttpRequest = new XMLHttpRequest();
        xmlHttpRequest.onreadystatechange = handleupdate;
        xmlHttpRequest.open("GET", "nsm_user_scheduledxferinfo.php", true);
        xmlHttpRequest.send();
    }
}

function handleupdate() {
    if(xmlHttpRequest.readyState == 4 && xmlHttpRequest.status == 200) {
        var jsonText = xmlHttpRequest.responseText;
        var objResponse = JSON.parse(jsonText);
        var tableElement = document.getElementById("xfertable");
        xmlHttpRequest = null;
        for(curObjKey in objResponse) {
            var curObj = objResponse[curObjKey];
            var curObjId = curObj['requestid'];
            if(!requests[curObjId]) {
                requests[curObjId] = curObj;
                tableElement.innerHTML += makeRowHTML(curObj);
            }else {
                updateRowHTML(curObj);
            }
        }
        
        setTimeout("requestupdate()", updateWait);
    }
}

function checkSizeDownloaded(object) {
    if(object['status'] ==  "inprogress" || object['status'] ==  "pause" || object['status'] ==  "req_pause") {
        if(parseInt(object['filesize']) <= 0) {
            //nothing really here right now...
            return 0;
        }else {
            return object['filesize'];
        }
    }else if(object['status'] == 'complete') {
        return object['total_size'];
    }else if(object['status'] == 'waiting') {
        if(parseInt(object['file_exists']) == 1) {
            return object['filesize'];
        }else {
            return 0;
        }
    }
}

/*
 * Generate the links for reschedule and pause
 */
function makeActionCell(object) {
    var requestID = object['requestid'];
    var html = "";
    if(object['status'] == "inprogress") {
        html += "<a href='./nsm_user_scheduledxfermgr.php?action=pause&amp;xferid="
            + requestID + "'>Pause</a>";
    }else if(object['status'] == "waiting" || object['status'] == "pause") {
        html += "<a href='#' onclick='reschedule(" + requestID + ")'>Reschedule</a>";
    }
    
    return html;
}

function formatRowCell(fieldname, object) {
    if(fieldname == "progress") {
        var progressPercent = 0;
        var downloadedAmount = checkSizeDownloaded(object);
        var totalSize = parseInt(object['total_size']);
        if(totalSize > 0) {
            progressPercent = (downloadedAmount / totalSize)*100;
        }else {
            progressPercent = 0;
        }
        return makeProgressBar(200, progressPercent)
    }else if(fieldname == 'downloaded') {
        return checkSizeDownloaded(object);
    }else if(fieldname == 'action') {
        return makeActionCell(object);
    }
    
    
    return object[fieldname];
    
}

function makeProgressBar(width, percentage) {
    var html = "<div style='border: 1px solid black; padding: 3px; width: " + width + "px'>";
    var progressBarWidth = (percentage / 100) * width;
    html += "<div style='width: " + progressBarWidth + "px; background-color: orange; height: 14px;'> </div>";
    html += "</div>";
    
    return html;
}

function makeRowHTML(object) {
    var html = "";
    var requestId = object['requestid'];
    html += "<tr id='request_tr_" + requestId + "'>";
    html += "<td id='request_time_" + requestId + "'>";
        + formatRowCell('start_time_formatted', object) + "</td>";
    html += "<td id='request_status_" + requestId + "'>"
        + formatRowCell('status', object) + "</td>";
    html += "<td id='request_url_" + requestId + "'>"
        + formatRowCell('url', object) + "</td>"
    html += "<td id='request_progress_" + requestId + "'>"
        + formatRowCell('progress', object) + "</td>";
    html += "<td id='request_downloaded_" + requestId + "'>"
        + formatRowCell('downloaded', object) + "</td>";
    html += "<td id='request_total_size_" + requestId + "'>"
        + formatRowCell('total_size', object) + "</td>";
    html += "<td id='request_action_" + requestId + "'>"
        + formatRowCell('action', object) + "</td>";
    html += "</tr>";
    
    return html;
}

function updateRowHTML(object) {
    var requestId = object['requestid'];
    document.getElementById("request_time_" + requestId).innerHTML = 
            formatRowCell("start_time_formatted", object);
    document.getElementById("request_status_" + requestId).innerHTML = 
            formatRowCell("status", object);
    document.getElementById("request_url_" + requestId).innerHTML = 
            formatRowCell("url", object);
    document.getElementById("request_progress_" + requestId).innerHTML =
            formatRowCell("progress", object);
    document.getElementById("request_downloaded_" + requestId).innerHTML = 
            formatRowCell('downloaded', object);
    document.getElementById("request_total_size_" + requestId).innerHTML =
            formatRowCell('total_size', object);
    document.getElementById("request_action_" + requestId).innerHTML = 
            formatRowCell('action', object);
}
