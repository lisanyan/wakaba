function get_cookie(name)
{
	with(document.cookie)
	{
		var regexp=new RegExp("(^|;\\s+)"+name+"=(.*?)(;|$)");
		var hit=regexp.exec(document.cookie);
		if(hit&&hit.length>2) return unescape(hit[2]);
		else return '';
	}
};

function set_cookie(name,value,days)
{
	if(days)
	{
		var date=new Date();
		date.setTime(date.getTime()+(days*24*60*60*1000));
		var expires="; expires="+date.toGMTString();
	}
	else expires="";
	document.cookie=name+"="+value+expires+"; path=/";
}

function get_password(name)
{
	var pass=get_cookie(name);
	if(pass) return pass;

	var chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	var pass='';

	for(var i=0;i<8;i++)
	{
		var rnd=Math.floor(Math.random()*chars.length);
		pass+=chars.substring(rnd,rnd+1);
	}

	return(pass);
}

function file_input_change(max) {
	var total = 0; // total number of file inputs
	var empty = 0; // number of empty file inputs

	// contains the file inputs and filename spans
	var postfiles = document.getElementById("fileInput");
	var inputs = postfiles.getElementsByTagName("input"); // actual file inputs

	for (i = 0; i < inputs.length; i++) {
		if (inputs[i].type != 'file') continue;

		total++;

		// no file selected
		if (inputs[i].value.length == 0) {
			empty++;
		} else {
			if (typeof inputs[i].files == "object" && inputs[i].files.length > 1)
				total += inputs[i].files.length - 1;
			inputs[i].style.display = "none";
		}
		update_file_label(inputs[i], max);
	}

	// less than "max" file inputs AND none of them empty: add new file input
	if (total < max && empty == 0) {
		var div = document.createElement("div");
		var input = document.createElement("input");

		input.type = "file";
		input.name = "file";
		input.onchange = function() {
			file_input_change(max)
		}

		div.appendChild(input);
		postfiles.appendChild(div);
	}
}

function update_file_label(fileinput, max) {
	// find a <span> next to the file input
	var el = fileinput.nextSibling;
	var found = false;
	var span;

	while (el && !found) {
		if (el.nodeName == "SPAN") {
			found = true;
			span = el;
		}
		el = el.nextSibling;
	}

	// add a new <span> to the dom if none was found
	if (!found) {
		var spacer = document.createTextNode("\n ");
		span = document.createElement("span");
		fileinput.parentNode.appendChild(spacer);
		fileinput.parentNode.appendChild(span);
	}

	// put file name(s) into span
	var filename = fileinput.value;

	if (filename.length == 0) {
		span.innerHTML = '';
		return;
	}

	var display_file = format_filename(filename);

	if (typeof fileinput.files == "object" && fileinput.files.length > 1) {
		for (var i = 1, l = fileinput.files.length; i < l; i++) {
			display_file += ' <br />\n&nbsp; '
				+ format_filename(fileinput.files[i].name);
		}
	}

	span.innerHTML = ' <a class="hide" href="javascript:void(0)"'
		+ ' onclick="del_file_input(this,' + max + ')">'
		+ '<img src="/img/cancel.png" width="16" height="16" title="'
		+ msg_remove_file + '" /></a> '
		+ display_file + '\n';
}

function format_filename(filename) {
	var filebase = "";  // file name with dot but without extension
	var extension = ""; // file extension without dot

	// remove path (if any)
	var lastIndex = filename.lastIndexOf("\\");
	if (lastIndex >= 0) {
		filename = filename.substring(lastIndex + 1);
	}

	// get file base name and file extension
	filebase = filename;
	extension = "";
	lastIndex = filename.lastIndexOf(".");
	if (lastIndex >= 0) {
		filebase = filename.substring(0, lastIndex + 1);
		extension = filename.substring(lastIndex + 1);
	}

	var result = filebase;
	if (filetype_allowed(extension)) {
		result += extension;
	} else {
		result += '<span class="adminname"><strong>' + extension + '</strong></span>';
	}

	return result;
}

function filetype_allowed(ext) {
	var extensions = filetypes.split(", ");
	for (var i = 0, l = extensions.length; i < l; i++) {
		if (extensions[i] == ext.toUpperCase()) return true;
	}
	return false;
}

function del_file_input(sender, max) {
	// <a>   <span>     <div>      <td>                  <a>    <span>    <div>
	sender.parentNode.parentNode.parentNode.removeChild(sender.parentNode.parentNode);
	file_input_change(max);
}


function insert(text)
{
	var textarea=document.forms.postform.field4;
	if(textarea)
	{
		if(textarea.createTextRange && textarea.caretPos) // IE
		{
			var caretPos=textarea.caretPos;
			caretPos.text=caretPos.text.charAt(caretPos.text.length-1)==" "?text+" ":text;
		}
		else if(textarea.setSelectionRange) // Firefox
		{
			var start=textarea.selectionStart;
			var end=textarea.selectionEnd;
			textarea.value=textarea.value.substr(0,start)+text+textarea.value.substr(end);
			textarea.setSelectionRange(start+text.length,start+text.length);
		}
		else
		{
			textarea.value+=text+" ";
		}
		textarea.focus();
	}
}

function highlight(post)
{
	var cells=document.getElementsByTagName("td");
	for(var i=0;i<cells.length;i++) if(cells[i].className=="highlight") cells[i].className="reply";

	var reply=document.getElementById("reply"+post);
	if(reply)
	{
		reply.className="highlight";
/*		var match=/^([^#]*)/.exec(document.location.toString());
		document.location=match[1]+"#"+post;*/
		return false;
	}

	return true;
}

function set_stylesheet_frame(styletitle,framename)
{
	set_stylesheet(styletitle);
	var list = get_frame_by_name(framename);
	if(list) set_stylesheet(styletitle,list);
}

function set_stylesheet(styletitle,target)
{
	set_cookie("wakabastyle",styletitle,365);

	var links = target ? target.document.getElementsByTagName("link") : document.getElementsByTagName("link");
	var found=false;
	for(var i=0;i<links.length;i++)
	{
		var rel=links[i].getAttribute("rel");
		var title=links[i].getAttribute("title");
		if(rel.indexOf("style")!=-1&&title)
		{
			links[i].disabled=true; // IE needs this to work. IE needs to die.
			if(styletitle==title) { links[i].disabled=false; found=true; }
		}
	}
	if(!found)
	{
		if(target) set_preferred_stylesheet(target);
		else set_preferred_stylesheet();
	}
}

function set_preferred_stylesheet(target)
{
	var links = target ? target.document.getElementsByTagName("link") : document.getElementsByTagName("link");
	for(var i=0;i<links.length;i++)
	{
		var rel=links[i].getAttribute("rel");
		var title=links[i].getAttribute("title");
		if(rel.indexOf("style")!=-1&&title) links[i].disabled=(rel.indexOf("alt")!=-1);
	}
}

function get_active_stylesheet()
{
	var links=document.getElementsByTagName("link");
	for(var i=0;i<links.length;i++)
	{
		var rel=links[i].getAttribute("rel");
		var title=links[i].getAttribute("title");
		if(rel.indexOf("style")!=-1&&title&&!links[i].disabled) return title;
	}
	return null;
}

function get_preferred_stylesheet()
{
	var links=document.getElementsByTagName("link");
	for(var i=0;i<links.length;i++)
	{
		var rel=links[i].getAttribute("rel");
		var title=links[i].getAttribute("title");
		if(rel.indexOf("style")!=-1&&rel.indexOf("alt")==-1&&title) return title;
	}
	return null;
}

function get_frame_by_name(name)
{
	var frames = window.parent.frames;
	for(i = 0; i < frames.length; i++)
	{
		if(name == frames[i].name) { return(frames[i]); }
	}
}

function set_inputs(id) {
	with (document.getElementById(id)) {
		if ((typeof field1 == "object") && (!field1.value))
			field1.value = get_cookie("name");
		if (typeof field2 == "object" && !field2.value) field2.value = get_cookie("email");
		if (typeof gb2 == "object")	gb2[1].checked = (get_cookie("gb2") == "thread");
		if (!password.value) password.value = get_password("password");

		// preload images for post form
		if (document.images) {
			new Image().src = "/img/cancel.png";
		}
	}
}

function set_delpass(id) {
	with (document.getElementById(id)) password.value = get_cookie("password");
}

function do_ban(el)
{
	var loc = el.href;
	var reason=prompt("Give a reason for this ban:");
	if(reason) loc+="&comment="+encodeURIComponent(reason);
	var flag=prompt("Flag post? (leave empty for no)");
	if(flag) document.location=loc+"&flag="+encodeURIComponent(flag);
	return false;
}

function expand_post(id) {
	//$j("#posttext_" + id).html($j("#posttext_full_" + id).html());
	var abbr = document.getElementById("posttext_" + id);
	var full = document.getElementById("posttext_full_" + id);
	abbr.innerHTML = full.innerHTML;
	return false;
}

// http://stackoverflow.com/a/7557433/5628
function isElementInViewport(el) {
	var rect = el.getBoundingClientRect();
	return (rect.top >= 0 && rect.left >= 0);
}

function expand_image(element, org_width, org_height, thumb_width, thumb_height, thumb) {
	// var img = element;
	var img = element.firstElementChild || element.children[0];
	var org = img.parentNode.href;
	var post = img.parentNode.parentNode.parentNode.parentNode.parentNode;

	if (img.src != org) {
		img.src = org;
		//img.style.maxWidth = "98%";
		var maxw = (window.innerWidth || document.documentElement.clientWidth) - 100;
		img.width = org_width < maxw ? org_width : maxw;
		img.style.height = "auto";
		//img.width = org_width;
		//img.height = org_height;
	} else {
		img.src = thumb;
		img.width = thumb_width;
		img.height = thumb_height;
		if (!isElementInViewport(post)) post.scrollIntoView();
	}
	UnTip();
	return false;
}

window.onunload=function(e)
{
	if(style_cookie)
	{
		var title=get_active_stylesheet();
		set_cookie(style_cookie,title,365);
	}
}

window.onload=function(e)
{
	var match;

	if(match=/#i([0-9]+)/.exec(document.location.toString()))
	if(!document.forms.postform.field4.value)
	insert(">>"+match[1]);

	if(match=/#([0-9]+)/.exec(document.location.toString()))
	highlight(match[1]);

	if(window.thread_id) $each(document.querySelectorAll('span.reflink a'), function (e) {
		e.onclick = function(ev){
			var a = ev.target,
			sel = window.getSelection().toString();
			ev.preventDefault();
			insert('>>' + a.href.match(/#i(\d+)$/)[1] + '\n' + (sel ? '>' + sel.replace(/\n/g, '\n>') + '\n' : ''));
		}
	});
}

if(style_cookie)
{
	var cookie=get_cookie(style_cookie);
	var title=cookie?cookie:get_preferred_stylesheet();
	set_stylesheet(title);
}
