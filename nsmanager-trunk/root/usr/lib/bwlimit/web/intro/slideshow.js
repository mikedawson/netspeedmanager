/*

Low Bandwidth Demo Script by Mike Dawson, PAIWASTOON Networking Services Ltd.

Licensed Under:
Creative Commons Attribution License 1.0

In order to use this script you *MUST* in a manner visible to the user attribute PAIWASTOON Networking Services Ltd. and link to www.paiwastoon.af .  

If you fail to do so we will contact your server provider and have action taken against you under the law of the country in which your server is based.

*/

var slideTemplateContainerElement ;

var slideContainerElement;

//The text descriptions (actually Elements, not strictly speaking Text Nodes)
var slideTextElements;

//The Image objects
var slideImages;

//The load status (false or true)
var slideImagesLoadStatus;

/* This can be over-ridden in the HTML */
var IMAGENAME_PRE = "sysdiagram";

var IMAGENAME_POST = ".png";

//The currently showing slide
var currentIndex = 0;

var numSlides = 0;

//Begin - fade parameters
var startOpacity = 0;

var currentImage = null;
var nextImage = null;
var step = 5.0;
var endOpacity = 100;
var fadeImagesList = new Array();
var delay = 50;

//End - fade parameters

//Begin - Typewriter parameters
var typeDelay = 50;
var typeCurrentPosition = 0;
var fullCommentStr;
//End - Typewriter parameters

//the table buttons
var tableButtons;

var STATE_LOADING = 0;
var STATE_READY = 1;
var STATE_ACTIVE = 2;

var STATESTYLE_COLOR = 0;
var STATESTYLE_BGCOLOR = 1;
var STATESTYLE_CURSOR = 2;

var tableButtonsStyles = new Array(
	new Array("white", "white", "white"),
	new Array("lightgray", "gray", "#ff3300"),
	new Array("wait", "pointer", "default")
);


function init() {
	slideTemplateContainerElement = document.getElementById("slidetemplatecontainer");
	slideContainerElement = document.getElementById("slideContainer");
	var nodeList = slideTemplateContainerElement.childNodes; 
	
	//check how many actual elements are in there
	var elementNodeCount = 0;
	for(var i = 0; i < nodeList.length; i++) {
		if(nodeList.item(i).nodeType == 1)
			elementNodeCount++;
	}
	numSlides = elementNodeCount;
	
	
	slideTextElements = new Array(elementNodeCount);
	slideImages = new Array(elementNodeCount);
	slideImagesLoadStatus = new Array(elementNodeCount);
	
	
	
	
	var elementCount = 0;
	for(var nodeIndex = 0; nodeIndex < nodeList.length; nodeIndex++) {
		if(nodeList.item(nodeIndex).nodeType ==1) {
			slideTextElements[elementCount] = nodeList.item(nodeIndex).cloneNode(true);
			slideImages[elementCount] = new Image();
			
			//start loading the picture
			slideImages[elementCount].src = IMAGENAME_PRE + elementCount + IMAGENAME_POST;
			slideImagesLoadStatus[elementCount] = false;
			slideImages[elementCount].onload = registerImageLoaded(elementCount);
			elementCount++;
		}
	}
	
	//make the control bar
	buildBar(document.getElementById("barContainer"));
	
}

function registerImageLoaded(index) {
	slideImagesLoadStatus[index] = true;
	if(index ==0) {
		//first image loaded, show it
		var imageElement = document.createElement("img");
		imageElement.src = slideImages[0].src;
		imageElement.style.position = 'absolute';
		imageElement.setAttribute('id', 'img'+index);
		currentImage = imageElement;
		slideContainerElement.appendChild(imageElement);
		fadeImagesList[0] = imageElement;
		
		changeText(0);
	}
	
	checkButtons();
	updateBar();
}

function changeSlide(nextIndex) {
	if(nextIndex == currentIndex) {
		return;//no change
	}
	
	//var nextIndex = currentIndex + increment;
	if(nextIndex < 0 || nextIndex >= numSlides) 
		return;
	
	if(!slideImagesLoadStatus[nextIndex]) {
		//this has not loaded yet - wait...
		return;
	}
	
	changeImage(nextIndex);
	changeText(nextIndex);
	
	currentIndex = nextIndex;
	
	checkButtons();
	updateBar();
}

function checkButtons() {
	var backEnabled = (currentIndex >= 1) && slideImagesLoadStatus[currentIndex-1];
	var fwdEnabled = (currentIndex < (numSlides-1)) && slideImagesLoadStatus[currentIndex+1];
	
	setButtonEnabled("backbutton", backEnabled);
	setButtonEnabled("forwardbutton", fwdEnabled);
}

function setButtonEnabled(buttonId, enabled) {
	var buttonElement = document.getElementById(buttonId);
	if(enabled) {
		buttonElement.style.cursor = 'pointer';
		buttonElement.style.color = 'white';
		buttonElement.style.borderStyle = 'outset';
		buttonElement.style.backgroundColor = 'gray';
	}else {
		buttonElement.style.cursor = 'default';
		buttonElement.style.color = 'black';
		buttonElement.style.borderStyle = 'ridge';
		buttonElement.style.backgroundColor = 'lightgray';
	}
}

function changeImage(nextIndex) {
	/*
	
	*/
	initXFade(nextIndex);
	
}

function changeText(nextIndex) {
	//document.getElementById("textContainer").innerHTML = slideTextElements[nextIndex].innerHTML;
	document.getElementById("textContainer").innerHTML = "";
	typeCurrentPos = 0;
	fullCommentStr = new String(slideTextElements[nextIndex].innerHTML);
	updateText(nextIndex);
}

function updateText(nextIndex) {
	document.getElementById("textContainer").innerHTML = fullCommentStr.substr(1, typeCurrentPos) + "<span class='typeCursor'>|</span>";
	typeCurrentPos++;
	if(typeCurrentPos < (fullCommentStr.length -1)) {
		setTimeout("updateText("+nextIndex+")", typeDelay);
	}
}

function initXFade(nextIndex) {
	
	
	var newImg =  document.createElement("img");
	newImg.src = slideImages[nextIndex].src;
	newImg.style.position = 'absolute';
	newImg.style.visibility = 'hidden';
	newImg.setAttribute("id", "img" + nextIndex);
	fadeImagesList[nextIndex] = newImg;
	
	var oldImg = currentImage;
	
	oldImg.opacity = 100;
	
	newImg.opacityIncrement = step;
	oldImg.opacityIncrement = -step;
	
	
	
	initFadeImage(currentIndex);
	initFadeImage(nextIndex);
	slideContainerElement.appendChild(newImg);
	
	//now add the new image to the pane
	
	
	//setTimeout("initXFade()", imgDelay);
	setTimeout("removeFadedOutImg("+currentIndex+")",  (((endOpacity-startOpacity)/step)+1)*delay );
	
}

function removeFadedOutImg(index) {
	slideContainerElement.removeChild(fadeImagesList[index]);
	fadeImagesList[index] = null;
}


/* 
 Counts the number of images loaded
 */
function countLoaded() {
	var loadedCount = 0;
	for(var i = 0; i < slideImagesLoadStatus.length; i++) {
		if(slideImagesLoadStatus[i]) loadedCount++;
	}
	return loadedCount;
}

function initFadeImage(index) {
	var obj = fadeImagesList[index];
	updateOpacity(index);
	obj.style.visibility = 'visible';
	
}


function updateOpacity (index) {
	var obj = fadeImagesList[index];
	if(obj == null) { //this one has been removed
		return;
	}
	
	var opacity = obj.opacity ? obj.opacity : startOpacity;
	opacity += obj.opacityIncrement;	
	setOpacity(obj, opacity);
	if(opacity != endOpacity) {
		setTimeout("updateOpacity("+index+")", delay);
	}
}




function setOpacity(obj, opacity) {
  opacity = (opacity == 100)?99.999:opacity;
  
  // IE/Win
  obj.style.filter = "alpha(opacity:"+opacity+")";
  
  // Safari<1.2, Konqueror
  obj.style.KHTMLOpacity = opacity/100;
  
  // Older Mozilla and Firefox
  obj.style.MozOpacity = opacity/100;
  
  // Safari 1.2, newer Firefox and Mozilla, CSS3
  obj.style.opacity = opacity/100;
  
  obj.opacity = opacity;
}

//function that generates the bar at the bottom that shows the current position and the loading status of the different images

function buildBar(container) {
	tableButtons = new Array(numSlides);
	var table = document.createElement("table");
	
	table.setAttribute("width", "690");
	table.setAttribute("border", "0");
	
	var tr = document.createElement("tr");
	table.appendChild(tr);
	for(var i = 0; i < numSlides; i++) {
		var td = document.createElement("td");
		td.innerHTML = i+1;
		td.setAttribute("onclick", "changeSlide("+i+")");
		tr.appendChild(td);
		td.style.textAlign = 'center';
		//td.onclick=changeSlide(i);
		
		tableButtons[i] = td;
	}
	container.appendChild(table);
	updateBar();
}

function updateBar() {
	if(!tableButtons) {
		//not ready yet
		return;
	}
	
	for(var i = 0; i < tableButtons.length; i++) {
		state = -1;
		if(currentIndex == i) {
			state = STATE_ACTIVE;
		}else if(slideImagesLoadStatus[i]) {
			state = STATE_READY;
		}else {
			state = STATE_LOADING;
		}
		
		tableButtons[i].style.backgroundColor = tableButtonsStyles[STATESTYLE_BGCOLOR][state];
		tableButtons[i].style.color = tableButtonsStyles[STATESTYLE_COLOR][state];
		tableButtons[i].style.cursor = tableButtonsStyles[STATESTYLE_CURSOR][state];
	}
}
