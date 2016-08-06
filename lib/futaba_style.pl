use strict;
use encoding 'utf8';

BEGIN {
	require "lib/post_view.pl";
	require "lib/wakautils.pl";
}

use constant NORMAL_HEAD_INCLUDE => q{

<!DOCTYPE html>
<html lang="en">
<head>
<title><if $title><var $title> - </if><const TITLE></title>
<meta charset="<const CHARSET>" />
<link rel="shortcut icon" href="<var FAVICON>" />

<link rel="stylesheet" type="text/css" href="<var root_path_to_filename('static/wakaba.css')>" />

<loop $stylesheets>
<link rel="<if !$default>alternate </if>stylesheet" type="text/css" href="<var $path><var $filename>" title="<var $title>" />
</loop>

<script type="text/javascript">var style_cookie="<const STYLE_COOKIE>";</script>
<script type="text/javascript" src="<var JS_FILE>"></script>
</head>
<if $thread><body class="replypage"></if>
<if !$thread><body></if>

}.include("include/header.html").q{

<div class="adminbar">
<loop $stylesheets>
	[<a href="javascript:set_stylesheet('<var $title>')"><var $title></a>]
</loop>
-
[<a href="<var expand_filename(HOME)>" target="_top"><const S_HOME></a>]
[<a href="<var get_secure_script_name()>?task=admin&amp;board=<var get_board_id()>"><const S_ADMIN></a>]
</div>

<div class="logo">
<if SHOWTITLEIMG==1><img src="<var root_path_to_filename(TITLEIMG)>" alt="<const TITLE>" /></if>
<if SHOWTITLEIMG==2><img src="<var root_path_to_filename(TITLEIMG)>" onclick="this.src=this.src;" alt="<const TITLE>" /></if>
<if SHOWTITLEIMG and SHOWTITLETXT><br /></if>
<if SHOWTITLETXT><const TITLE></if>
</div><hr />
};

use constant NORMAL_FOOT_INCLUDE => include("include/footer.html").q{

</body></html>
};

use constant PAGE_TEMPLATE => compile_template(NORMAL_HEAD_INCLUDE.q{

<if $thread && !$locked>
	[<a href="<var expand_filename(HTML_SELF)>"><const S_RETURN></a>]
	<div class="theader"><const S_POSTING></div>
</if>

<if $postform>
	<div class="postarea">
	<form id="postform" action="<var $self>" method="post" enctype="multipart/form-data">

	<input type="hidden" name="task" value="post" />
	<input type="hidden" name="board" value="<var get_board_id()>">
	<if $thread><input type="hidden" name="parent" value="<var $thread>" /></if>
	<if !$image_inp and !$thread and ALLOW_TEXTONLY>
		<input type="hidden" name="nofile" value="1" />
	</if>
	<if FORCED_ANON><input type="hidden" name="name" /></if>
	<if SPAM_TRAP><div class="trap"><const S_SPAMTRAP><input type="text" name="name" size="28" autocomplete="off" /><input type="text" name="link" size="28" autocomplete="off" /></div></if>

	<table><tbody>
	<if !FORCED_ANON><tr><td class="postblock"><const S_NAME></td><td><input type="text" name="field1" size="28" /></td></tr></if>
	<tr><td class="postblock"><const S_SUBJECT></td><td><input type="text" name="field3" size="35" />
	<input type="submit" value="<const S_SUBMIT>" /></td></tr>
	<if !ALLOW_LINK && $thread><tr><td class="postblock"><const S_SAGE></td><td><label><input type="checkbox" name="field2" value="sage" /><const S_SAGEDESC></label></td></tr>
	<elsif ALLOW_LINK><tr><td class="postblock"><const S_EMAIL></td><td><input type="text" name="field2" size="28" /></td></tr></if>
	<tr><td class="postblock"><const S_COMMENT></td><td><textarea name="field4" cols="60" rows="6"></textarea></td></tr>

	<if $image_inp>
		<tr><td class="postblock"><const S_UPLOADFILE></td><td><input type="file" name="file" size="35" />
		<if $textonly_inp>[<label><input type="checkbox" name="nofile" value="on" /><const S_NOFILE> ]</label></if>
		</td></tr>
	</if>

	<if ENABLE_CAPTCHA>
		<tr><td class="postblock"><const S_CAPTCHA></td><td><input type="text" name="captcha" size="10" />
		<img alt="" src="<var CAPTCHA_SCRIPT>?board=<var get_board_id()>&amp;key=<var get_captcha_key($thread)>&amp;dummy=<var $dummy>" />
		</td></tr>
	</if>

	<tr><td class="postblock"><const S_DELPASS></td><td><input type="password" name="password" size="8" /> <const S_DELEXPL></td></tr>
	<tr><td colspan="2">
	<div class="rules">}.include("include/rules.html").q{</div></td></tr>
	</tbody></table></form></div>
	<if !$locked><script type="text/javascript">set_inputs("postform")</script></if>
</if>

<if $locked>
[<a href="<var expand_filename(HTML_SELF)>"><const S_RETURN></a>]
<p class="locked"><var sprintf S_THREADLOCKED, $thread></p>
</if>

<hr />

<form id="delform" action="<var $self>" method="post">
<input type="hidden" name="board" value="<var get_board_id()>">

<loop $threads>
	<loop $posts>
}.POST_VIEW_INCLUDE.q{
	</loop>
	</div>
	<br style="clear:left" /><hr />
</loop>

<table class="userdelete"><tbody><tr><td>
<const S_REPDEL>[<label><input type="checkbox" name="fileonly" value="on" /><const S_DELPICONLY></label>]<br />
<const S_DELKEY><input type="password" name="password" size="8" autocomplete="off" />
<input name="task" value="<const S_DELETE>" type="submit" />
<if ENABLE_REPORTS><input name="task" value="<const S_REPORT>" type="submit" /></if>
</td></tr></tbody></table>
</form>
<script type="text/javascript">set_delpass("delform")</script>

<if !$thread>
	<table border="1"><tbody><tr><td>

	<if $prevpage><form method="get" action="<var $prevpage>"><input value="<const S_PREV>" type="submit" /></form></if>
	<if !$prevpage><const S_FIRSTPG></if>

	</td><td>

	<loop $pages>
		<if !$current>[<a href="<var $filename>"><var $page></a>]</if>
		<if $current>[<var $page>]</if>
	</loop>

	</td><td>

	<if $nextpage><form method="get" action="<var $nextpage>"><input value="<const S_NEXT>" type="submit" /></form></if>
	<if !$nextpage><const S_LASTPG></if>

	</td></tr></tbody></table><br style="clear:both;" />
</if>

<if $thread><br style="clear:both;"></if>
}.NORMAL_FOOT_INCLUDE);

use constant POST_REPORT_TEMPLATE => compile_template(NORMAL_HEAD_INCLUDE.q{
[<a href="<var expand_filename(HTML_SELF)>"><const S_RETURN></a>]
<div class="theader"><const S_REPORTHEAD></div>
<div align="center">
	<h3><const S_REPORTEXPL></h3>
	<h3><loop $posts>
	&nbsp;<a href="<var get_reply_link($num,$parent)>"><var $num></a>&nbsp;
	</loop></h3>
	<h3><label for="reason"><const S_REPORTREASON></label></h3>
	<form action="<var $self>" method="post">
	<input type="hidden" name="board" value="<var get_board_id()>">
	<input type="hidden" name="sent" value="1" />
	<loop $posts><input type="hidden" name="delete" value="<var $num>" /></loop>
	<input type="text" name="reason" id="reason" value="" size="32" />
	<input type="submit" name="task" value="<const S_REPORT>" />
	</form>
</div>
<br /><hr />
}.NORMAL_FOOT_INCLUDE);


use constant POST_REPORT_SUCCESSFUL => compile_template(NORMAL_HEAD_INCLUDE.q{
<div align="center">
<h1><const S_REPORTSUCCESS></h1>
<br />
<h1><a href="<var expand_filename(HTML_SELF)>"><const S_RETURN></a></h1>
<br />
</div>
<hr />
}.NORMAL_FOOT_INCLUDE);

use constant ERROR_TEMPLATE => compile_template(NORMAL_HEAD_INCLUDE.q{

<if $error><h1 style="text-align: center"><var $error></if>

<if $banned or $dnsbl><h2 style="text-align: center">
<div class="info">
<loop $bans>
 Your IP <strong><var $ip></strong>
 <if $showmask>(<var $network>/<var $setbits>)</if> has been banned
 <if $reason>with reason <em><var $reason></em>.</if><br />
 <if $expires>This lock will expire on <strong><var make_date($expires, "2ch")></strong>.</if>
 <if !$expires>This lock is valid for an indefinite period.</if><br />
</loop>
<span>Due to this fact, you're not allowed to post now. Please contact admin if you want to post again!</span>
</div>
</if>
<br />
<a href="<var escamp($ENV{HTTP_REFERER})>"><const S_RETURN></a><br /><br />
</h1>

}.NORMAL_FOOT_INCLUDE);



#
# Admin pages
#

use constant MANAGER_HEAD_INCLUDE => NORMAL_HEAD_INCLUDE.q{

[<a href="<var expand_filename(HTML_SELF)>"><const S_MANARET></a>]
<if $admin>
	[<a href="<var $self>?task=mpanel&amp;board=<var get_board_id()>"><const S_MANAPANEL></a>]
	[<a href="<var $self>?task=bans&amp;board=<var get_board_id()>"><const S_MANABANS></a>]
	[<a href="<var $self>?task=reports&amp;board=<var get_board_id()>"><const S_MANAREPORTS></a>]
	[<a href="<var $self>?task=rebuild&amp;board=<var get_board_id()>"><const S_MANAREBUILD></a>]
	[<a href="<var $self>?task=logout&amp;board=<var get_board_id()>"><const S_MANALOGOUT></a>]
</if>
<div class="passvalid"><const S_MANAMODE></div><br />
};

use constant ADMIN_LOGIN_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{

<div align="center"><form action="<var $self>" method="post">
<input type="hidden" name="board" value="<var get_board_id()>">
<input type="hidden" name="task" value="admin" />
<div>
<label><const S_ADMINPASS> <input type="password" name="berra" size="8" value="" /></label>
<br />
<label><input type="checkbox" name="savelogin" /> <const S_MANASAVE></label>
<br />
<select name="nexttask">
<option value="mpanel"><const S_MANAPANEL></option>
<option value="bans"><const S_MANABANS></option>
<option value="reports"><const S_MANAREPORTS></option>
<option value="rebuild"><const S_MANAREBUILD></option>
</select>
<input type="submit" value="<const S_MANASUB>" />
</div>
</form></div>

}.NORMAL_FOOT_INCLUDE);


use constant POST_PANEL_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{

<div class="dellist"><const S_MANAPOST></div>

<div class="postarea">
<form id="postform" action="<var $self>" method="post" enctype="multipart/form-data">
<input type="hidden" name="board" value="<var get_board_id()>">
<input type="hidden" name="task" value="post" />
<input type="hidden" name="no_format" value="1" />

<table><tbody>
<tr><td class="postblock"><const S_NAME></td><td><input type="text" name="field1" size="28" /></td></tr>
<tr><td class="postblock"><const S_EMAIL></td><td><label><input type="text" name="field2" size="35" /><if !ALLOW_LINK> <em>(sage only)</em></if></td></tr>
<tr><td class="postblock"><const S_SUBJECT></td><td><input type="text" name="field3" size="35" />
<input type="submit" value="<const S_SUBMIT>" /></td></tr>
<tr><td class="postblock"><const S_OPTIONS></td>
<td><label><input type="checkbox" name="as_staff" value="1" /> <const S_POSTASADMIN>
<label><input type="checkbox" name="no_format" value="1" /> <const S_NOTAGS2></label>
</label></td></tr>
<tr><td class="postblock"><const S_COMMENT></td><td><textarea name="field4" cols="60" rows="6"></textarea></td></tr>
<tr><td class="postblock"><const S_UPLOADFILE></td><td><input type="file" name="file" size="35" />
[<label><input type="checkbox" name="nofile" value="on" /><const S_NOFILE> ]</label>
</td></tr>
<tr><td class="postblock"><const S_PARENT></td><td><input type="text" name="parent" size="8" /></td></tr>
<tr><td class="postblock"><const S_DELPASS></td><td><input type="password" name="password" size="8" /><const S_DELEXPL></td></tr>
</tbody></table></form></div>
<script type="text/javascript">set_inputs("postform")</script>
<br  />

<div class="dellist"><const S_MANAPANEL></div>

<form action="<var $self>" method="post">
<input type="hidden" name="board" value="<var get_board_id()>">
<input type="hidden" name="task" value="delete" />

<div class="delbuttons">
<input type="submit" value="<const S_MPDELETE>" />
<input type="submit" name="archive" value="<const S_MPARCHIVE>" />
<input type="reset" value="<const S_MPRESET>" />
[<label><input type="checkbox" name="fileonly" value="on" /><const S_MPONLYPIC></label>]
</div>

<table align="center" style="white-space: nowrap"><tbody>
<tr class="managehead"><const S_MPTABLE></tr>

<loop $posts>
	<if !$parent><tr class="managehead"><th colspan="6"></th></tr></if>

	<tr class="row<var $rowtype>">

	<if !$image><td></if>
	<if $image><td rowspan="2"></if>
	<label><input type="checkbox" name="delete" value="<var $num>" /><span style="font-size: larger;"><strong><var $num></strong></span>&nbsp;&nbsp;</label></td>

	<td><var make_date($timestamp,"tiny")></td>
	<td><var clean_string(substr $subject,0,20)></td>
	<td><b><var clean_string(substr $name,0,30)><var $trip></b></td>
	<td><var clean_string(substr $comment,0,50)></td>
	<td><var dec_to_dot($ip)>
		[<a href="<var $self>?task=deleteall&amp;board=<var get_board_id()>&amp;ip=<var $ip>"><const S_MPDELETEALL></a>]
		[<a href="<var $self>?task=addip&amp;board=<var get_board_id()>&amp;type=ipban&amp;ip=<var $ip>&amp;postid=<var $num>" onclick="return do_ban(this)"><const S_MPBAN></a>]
		<if !$parent>
			[<a href="<var $self>?board=<var get_board_id()>&amp;task=lock&amp;thread=<var $num>" title="<const S_MPLOCK>"><if $locked>-</if>L</a>]
			[<a href="<var $self>?board=<var get_board_id()>&amp;task=kontra&amp;thread=<var $num>" title="<const S_MPAUTOSAGE>"><if $autosage>-</if>AS</a>]
		</if>
	</td>

	</tr>
	<if $image>
		<tr class="row<var $rowtype>">
		<td colspan="5"><small>
		<const S_PICNAME><a href="<var expand_filename(clean_path($image))>"><var clean_string($image)></a>
		(<var make_size($size)>, <var $width>x<var $height>)&nbsp; MD5: <var $md5>
		</small></td></tr>
	</if>
</loop>

</tbody></table>

<div class="delbuttons">
<input type="submit" value="<const S_MPDELETE>" />
<input type="submit" name="archive" value="<const S_MPARCHIVE>" />
<input type="reset" value="<const S_MPRESET>" />
[<label><input type="checkbox" name="fileonly" value="on" /><const S_MPONLYPIC></label>]
</div>

</form>

<table border="1" align="center"><tbody><tr>
	<td>
		<if defined $prev>
			<form method="get" action="<var $self>">
				<input type="hidden" name="task" value="mpanel" />
				<input type="hidden" name="board" value="<var get_board_id()>" />
				<input type="hidden" name="page" value="<var $prev>" />
				<input type="submit" value="<const S_PREV>" />
			</form>
		<else>
			<const S_FIRSTPG>
		</if>
	</td>
	<td>
		<loop $pages>
			<if !$current>
				[<a href="<var $url>"><var $page></a>]
			<else>
				[<var $page>]
			</if>
		</loop>
	</td>
	<td>
		<if defined $next>
			<form method="get" action="<var $self>">
				<input type="hidden" name="task" value="mpanel" />
				<input type="hidden" name="board" value="<var get_board_id()>" />
				<input type="hidden" name="page" value="<var $next>" />
				<input type="submit" value="<const S_NEXT>" />
			</form>
		<else>
			<const S_LASTPG>
		</if>
	</td>
</tr></tbody></table>

<br />

<div class="postarea">
<form action="<var $self>" method="post">
<input type="hidden" name="board" value="<var get_board_id()>">
<input type="hidden" name="task" value="deleteall" />
<table><tbody>
<tr><td class="postblock"><const S_BANIPLABEL></td><td><input type="text" name="ip" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANMASKLABEL></td><td><input type="text" name="mask" size="24" />
<input type="submit" value="<const S_MPDELETEIP>" /></td></tr>
</tbody></table></form>
</div><br />

<var sprintf S_IMGSPACEUSAGE,make_size($size)>

}.NORMAL_FOOT_INCLUDE);

use constant DELETE_PANEL_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{
<div class="dellist"><const S_MPDELETEIP></div>
<div class="postarea">
<form action="<var $self>" method="post">
<input type="hidden" name="task" value="deleteall" />
<input type="hidden" name="board" value="<var get_board_id()>" />
<input type="hidden" name="ip" value="<var $ip>" />
<input type="hidden" name="mask" value="<var dec_to_dot($mask)>" />
<input type="hidden" name="go" value="1" />
<table><tbody>
<tr><td class="postblock"><const S_BANIPLABEL></td><td><var dec_to_dot($ip)></td></tr>
<tr><td class="postblock"><const S_BANMASKLABEL></td><td><var dec_to_dot($mask)></tr>
<tr><td class="postblock"><const S_BOARD></td><td>/<var get_board_id()>/</tr>
<tr><td class="postblock"><const S_DELALLMSG></td><td><var sprintf S_DELALLCOUNT, $posts, $threads>
<input type="submit" value="<const S_MPDELETEIP>" /></td></tr>
</tbody></table></form>
</div>
}.NORMAL_FOOT_INCLUDE);

use constant BAN_PANEL_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{

<div class="dellist"><const S_MANABANS></div>

<div class="postarea">
<table><tbody><tr><td valign="bottom">

<form action="<var $self>" method="post">
<input type="hidden" name="board" value="<var get_board_id()>">
<input type="hidden" name="task" value="addip" />
<input type="hidden" name="type" value="ipban" />
<table><tbody>
<tr><td class="postblock"><const S_BANIPLABEL></td><td><input type="text" name="ip" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANMASKLABEL></td><td><input type="text" name="mask" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANCOMMENTLABEL></td><td><input type="text" name="comment" size="16" />
<input type="submit" value="<const S_BANIP>" /></td></tr>
<tr><td class="postblock"><const S_BANEXPIRESLABEL></td><td>
<if scalar BAN_DATES>
	<select name="expires">
		<loop BAN_DATES>
			<option value="<var $label>"><var clean_string($label)></option>
		</loop>
	</select>
<else>
	<input type="text" name="expires" size="16" />
	<small><const S_BANSECONDS></small>
</if>
</td></tr>
</tbody></table></form>

</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td valign="bottom">

<form action="<var $self>" method="post">
<input type="hidden" name="board" value="<var get_board_id()>">
<input type="hidden" name="task" value="addip" />
<input type="hidden" name="type" value="whitelist" />
<table><tbody>
<tr><td class="postblock"><const S_BANIPLABEL></td><td><input type="text" name="ip" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANMASKLABEL></td><td><input type="text" name="mask" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANCOMMENTLABEL></td><td><input type="text" name="comment" size="16" />
<input type="submit" value="<const S_BANWHITELIST>" /></td></tr>
<tr><td class="postblock"><const S_BANEXPIRESLABEL></td><td>
<if scalar BAN_DATES>
	<select name="expires">
		<loop BAN_DATES>
			<option value="<var $label>"><var clean_string($label)></option>
		</loop>
	</select>
<else>
	<input type="text" name="expires" size="16" />
	<small><const S_BANSECONDS></small>
</if>
</td></tr>
</tbody></table></form>

</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td></tr><tr><td valign="bottom">

<form action="<var $self>" method="post">
<input type="hidden" name="board" value="<var get_board_id()>">
<input type="hidden" name="task" value="addstring" />
<input type="hidden" name="type" value="wordban" />
<table><tbody>
<tr><td class="postblock"><const S_BANWORDLABEL></td><td><input type="text" name="string" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANCOMMENTLABEL></td><td><input type="text" name="comment" size="16" />
<input type="submit" value="<const S_BANWORD>" /></td></tr>
<tr><td class="postblock"><const S_BANEXPIRESLABEL></td><td>
<if scalar BAN_DATES>
	<select name="expires">
		<loop BAN_DATES>
			<option value="<var $label>"><var clean_string($label)></option>
		</loop>
	</select>
<else>
	<input type="text" name="expires" size="16" />
	<small><const S_BANSECONDS></small>
</if>
</td></tr>
</tbody></table></form>

</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td valign="bottom">

<form action="<var $self>" method="post">
<input type="hidden" name="board" value="<var get_board_id()>">
<input type="hidden" name="task" value="addstring" />
<input type="hidden" name="type" value="trust" />
<table><tbody>
<tr><td class="postblock"><const S_BANTRUSTTRIP></td><td><input type="text" name="string" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANCOMMENTLABEL></td><td><input type="text" name="comment" size="16" />
<input type="submit" value="<const S_BANTRUST>" /></td></tr>
<tr><td class="postblock"><const S_BANEXPIRESLABEL></td><td>
<if scalar BAN_DATES>
	<select name="expires">
		<loop BAN_DATES>
			<option value="<var $label>"><var clean_string($label)></option>
		</loop>
	</select>
<else>
	<input type="text" name="expires" size="16" />
	<small><const S_BANSECONDS></small>
</if>
</td></tr>
</tbody></table></form>

</td></tr></tbody></table>
</div><br />

<table align="center"><tbody>
<tr class="managehead"><const S_BANTABLE></tr>

<loop $bans>
	<if $divider><tr class="managehead"><th colspan="7"></th></tr></if>

	<tr class="row<var $rowtype>">

	<if $type eq 'ipban'>
		<td>IP</td>
		<td><if $date><var make_date($date, '2ch')><else><em>undefined</em></if></td>
		<td><if $expires><var make_date($expires, '2ch')><else><const S_BANEXPIRESNEVER></if></td>
		<td><var dec_to_dot($ival1,$sval1)></td><td><var dec_to_dot($ival2,$sval1)></td>
	</if>
	<if $type eq 'wordban'>
		<td>Word</td>
		<td><if $date><var make_date($date, '2ch')><else><em>undefined</em></if></td>
		<td><if $expires><var make_date($expires, '2ch')><else><const S_BANEXPIRESNEVER></if></td>
		<td colspan="2"><var $sval1></td>
	</if>
	<if $type eq 'trust'>
		<td>NoCap</td>
		<td><if $date><var make_date($date, '2ch')><else><em>undefined</em></if></td>
		<td><if $expires><var make_date($expires, '2ch')><else><const S_BANEXPIRESNEVER></if></td>
		<td colspan="2"><var $sval1></td>
	</if>
	<if $type eq 'whitelist'>
		<td>Whitelist</td>
		<td><if $date><var make_date($date, '2ch')><else><em>undefined</em></if></td>
		<td><if $expires><var make_date($expires, '2ch')><else><const S_BANEXPIRESNEVER></if></td>
		<td><var dec_to_dot($ival1)></td><td><var dec_to_dot($ival2)></td>
	</if>

	<td><var $comment></td>
	<td><a href="<var $self>?board=<var get_board_id()>&amp;task=removeban&amp;num=<var $num>"><const S_BANREMOVE></a></td>
	</tr>
</loop>

</tbody></table><br />

}.NORMAL_FOOT_INCLUDE);

use constant REPORTS_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{
<div class="dellist"><const S_MANAREPORTS></div>
<form action="<var $self>" method="POST">
<input type="hidden" name="board" value="<var get_board_id()>">
<input type="hidden" name="task" value="dismiss" />
<div class="delbuttons">
<input type="submit" value="<const S_REPORTSDISMISS>" />
</div>
<table align="center"><tbody>
<tr class="managehead">
<th><const S_REPORTSNUM></th>
<th><const S_REPORTSBOARD></th>
<th><const S_REPORTSDATE></th>
<th><const S_REPORTSCOMMENT></th>
<th><const S_REPORTSIP></th>
<th><const S_REPORTSDISMISS></th>
</tr>
<loop $reports>
	<if $divider><tr class="managehead"><th colspan="6"></th></tr></if>
	<tr class="row<var $rowtype>">
		<td><input type="checkbox" name="num" value="<var $num>" /><a href="<var get_reply_link($post,$parent,$board)>"><big><b><var $post></b></big></a>&nbsp;&nbsp;</td>
		<td>/<var $board>/</td>
		<td><var make_date($date,'tiny')></td>
		<td><var clean_string($reason)></td>
		<td><var $ip></td>
		<td>[<a href="<var $self>?task=dismiss&amp;board=<var get_board_id()>&amp;num=<var $num>"><const S_REPORTSDISMISS></a>]</td>
	</tr>
</loop>
</tbody></table>
<div class="delbuttons">
<input type="submit" value="<const S_REPORTSDISMISS>" />
</div>
</form>
}.NORMAL_FOOT_INCLUDE);


no encoding;

no strict;
$stylesheets=get_stylesheets(); # make stylesheets visible to the templates
use strict;

sub get_filename($) { my $path=shift; $path=~m!([^/]+)$!; clean_string($1) }

sub show_filename($) {
	my ($filename)=@_;
	my ($name,$ext)=$filename=~/^(.*)(\.[^\.]+$)/;
	length($name)>25
		? clean_string(substr($name, 0, 25)."(...)$ext")
		: clean_string($filename);
}

sub make_size($) {
	my $size=shift or return "0 B";
	my @s=qw(B kB MB GB);
	for(0..3) { return sprintf "%0.2f $s[$_]",$size/1024**$_ if $size>=1024**$_ and $size<1024**($_+1); }
	return sprintf("%0.2f TB",$size/1024**4); # should we even bother?
}

sub get_stylesheets()
{
	my $found=0;
	my @stylesheets=map
	{
		my %sheet;

		$sheet{filename}=$_;
		# $sheet{filename} =~ s/^.*\///;

		($sheet{title})=m!([^/]+)\.css$!i;
		$sheet{title}=ucfirst $sheet{title};
		$sheet{title}=~s/_/ /g;
		$sheet{title}=~s/ ([a-z])/ \u$1/g;
		$sheet{title}=~s/([a-z])([A-Z])/$1 $2/g;

		if($sheet{title} eq DEFAULT_STYLE) { $sheet{default}=1; $found=1; }
		else { $sheet{default}=0; }

		\%sheet;
	} glob(CSS_DIR."*.css");

	$stylesheets[0]{default}=1 if(@stylesheets and !$found);

	return \@stylesheets;
}

1;
