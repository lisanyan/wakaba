var doc = document;
var postByNum = [];
var ajaxPosts = {};
var refArr = [];

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
			new Image().src = "/img/icons/cancel.png";
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

// =======================================================================
// ЛЮТЫЙ НЕГР ЗАСТРЯЛ В УКУПНИКЕ АААААААААААААААААААААААААААААААААА
function $X(path, root) {
    return doc.evaluate(path, root || doc, null, 6, null);
}
function $x(path, root) {
    return doc.evaluate(path, root || doc, null, 8, null).singleNodeValue;
}
function $del(el) {
    if(el) el.parentNode.removeChild(el);
}
function $each(arr, fn) {
	for(var el, i = 0; el = arr[i++];)
		fn(el);
}
function $each_x(list, fn) {
    if(!list) return;
    var i = list.snapshotLength;
    if(i > 0) while(i--) fn(list.snapshotItem(i), i);
}

function delPostPreview(e) {
    var el = $x('ancestor-or-self::*[starts-with(@id,"pstprev")]', e.relatedTarget);
    if(!el) $each_x($X('.//div[starts-with(@id,"pstprev")]'), function(clone) { $del(clone); });
    else while(el.nextSibling) $del(el.nextSibling);
}

function showPostPreview(e) {
    var tNum = this.pathname.substring(this.pathname.lastIndexOf('/')).match(/\d+/);
    var pNum = this.hash.match(/\d+/) || tNum;
    var brd = decodeURIComponent(this.pathname.match(/[^\/]+/));
    var x = e.clientX + (doc.documentElement.scrollLeft || doc.body.scrollLeft) - doc.documentElement.clientLeft + 1;
    var y = e.clientY + (doc.documentElement.scrollTop || doc.body.scrollTop) - doc.documentElement.clientTop;
    var cln = doc.createElement('div');
    cln.id = 'pstprev_' + pNum;
    cln.className = 'reply';
    cln.style.cssText = 'position:absolute; z-index:950; border:solid 1px #575763; top:' + y + 'px;' +
        (x < doc.body.clientWidth/2 ? 'left:' + x + 'px' : 'right:' + parseInt(doc.body.clientWidth - x + 1) + 'px');
    cln.addEventListener('mouseout', delPostPreview, false);
    var aj = ajaxPosts[tNum];
    var functor = function(cln, html) {
        cln.innerHTML = html;
        doRefPreview(cln);
        if(!$x('.//small', cln) && ajaxPosts[tNum] && ajaxPosts[tNum][pNum] && refArr[pNum])
            showRefMap(cln, pNum, tNum, brd);
    };
    cln.innerHTML = 'Загрузка...';
    if(postByNum[pNum]) functor(cln, postByNum[pNum].innerHTML);
    else {
		var postURI = '/wakaba.pl?board=' + brd + '&task=showpost&post=' + pNum;
		if(aj && aj[pNum]) functor(cln, aj[pNum]);
        else AJAX(brd, postURI, function(err) { functor(cln, err || ajaxPosts[tNum][pNum] || 'Пост не найден'); });
    };
    $del(doc.getElementById(cln.id));
    $x('.//form[@id="delform"]').appendChild(cln);
}

function doRefPreview(node) {
    $each_x($X('.//a[starts-with(text(),">>")]', node || doc), function(link) {
        link.addEventListener('mouseover', showPostPreview, false);
        link.addEventListener('mouseout', delPostPreview, false);
    });
}

function getRefMap(post, pNum, rNum) {
    if(!refArr[rNum]) refArr[rNum] = pNum;
    else if(refArr[rNum].indexOf(pNum) == -1) refArr[rNum] = pNum + ', ' + refArr[rNum];
}

function showRefMap(post, pNum, tNum, brd) {
    var ref = refArr[pNum].toString().replace(/(\d+)/g,
    '<a href="' + (tNum ? '/' + brd + '/res/' + tNum + '.html#$1' : '#$1') + '" onclick="highlight($1)">&gt;&gt;$1</a>');
    var map = doc.createElement('small');
    map.id = 'rfmap_' + pNum;
    map.innerHTML = '<br><i class="abbrev">&nbsp;Ответы: ' + ref + '</i><br>';
    doRefPreview(map);
    if(post) post.appendChild(map);
    else {
        var el = $x('.//a[@name="' + pNum + '"]');
        while(el.tagName != 'BLOCKQUOTE') el = el.nextSibling;
        el.parentNode.insertBefore(map, el.nextSibling);
    }
}

function doRefMap(node) {
    $each_x($X('.//a[starts-with(text(),">>")]', node || doc), function(link) {
        if(!/\//.test(link.textContent)) {
            var rNum = link.hash.match(/\d+/);
            var post = $x('./ancestor::td', link);
            if((postByNum[rNum] || $x('.//a[@id="' + rNum + '"]')) && post)
                getRefMap(post, post.id.match(/\d+/), rNum);
        }
    });
    for(var rNum in refArr)
        showRefMap(postByNum[rNum], rNum);
}

function AJAX(b, url, fn) {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if(xhr.readyState != 4) return;
        if(xhr.status == 200) {
            var x = xhr.responseText;
			parser = new DOMParser();
			var docu = parser.parseFromString(x, "text/html")
			var tNum = docu.querySelector('.thr').id;
			ajaxPosts[tNum] = {keys: []};
			$each_x($X('.//td[@class="reply"]', docu), function(post) {
				var pNum = post.id.match(/\d+/);
				postByNum[pNum] = post;
				ajaxPosts[tNum].keys.push(pNum);
				ajaxPosts[tNum][pNum] = post.innerHTML;
			});
			fn();
        } else fn('HTTP ' + xhr.status + ' ' + xhr.statusText);
    };
    xhr.open('GET', url, true);
    xhr.send(false);
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

	$each_x($X('.//td[@class="reply"]'), function(post) { postByNum[post.id.match(/\d+/)] = post; });
    doRefPreview();
    doRefMap();
}

if(style_cookie)
{
	var cookie=get_cookie(style_cookie);
	var title=cookie?cookie:get_preferred_stylesheet();
	set_stylesheet(title);
}
