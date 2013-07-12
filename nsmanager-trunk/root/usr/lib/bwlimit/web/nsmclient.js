/* 
 * Net Speed Manager client functions
 */


/**
 * This will check that a time is a valid hh:mm (24hr) time
 */
function validateTime(timeval) {
    var timeStr = new String(timeval);
    var timeParts = timeStr.split(":");
    if(timeParts.length != 2) {
        return false;
    }

    var hrsInt = parseInt(timeParts[0]);
    var minsInt = parseInt(timeParts[1]);

    if(hrsInt < 0 || hrsInt > 23) {
        return false;
    }

    if(minsInt < 0 || minsInt > 59) {
        return false;
    }

    return true;
}


