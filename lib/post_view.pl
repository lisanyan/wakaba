# post include

use constant POST_VIEW_INCLUDE => q{
<if !$parent && !$single>
<div id="t<var $num>_info" style="float:left"></div>
<if !$thread><span id="t<var $num>_display" style="float:right"><a href="javascript:threadHide('t<var $num>')" id="togglet<var $num>"><const S_HIDETHREAD></a><ins><noscript><br/>(Javascript Required.)</noscript></ins></span></if>
<div id="t<var $num>">
</if>

<if $parent || $single>
<table><tbody><tr>
<td class="doubledash"><a href="<var get_reply_link($parent,0)>#<var $num>">&gt;&gt;</a></td>
<td class="reply" id="reply<var $num>">
</if>

<a id="<var $num>"></a>

<label>
	<input type="checkbox" name="delete" value="<var $num>" />
	<if !$parent><span class="filetitle"><else><span class="replytitle"></if><var $subject></span>
	<if $email><span class="postername"><a href="<var $email>"><if $adminpost><span class="adminname"><var $name></span><else><var $name></if></a></span><if $trip><span class="postertrip"><a href="<var $email>"><var $trip></a></span></if><if DISPLAY_ID && !$adminpost><span class="posterid">ID: <var make_id_code(dec_to_dot($ip), $timestamp, $email)></span></if></span></if>
	<if !$email><span class="postername"><if $adminpost><span class="adminname"><var $name><else><var $name></if></span><if $trip><span class="postertrip"><var $trip></span></if><if DISPLAY_ID && !$adminpost> <span class="posterid">ID: <var make_id_code(dec_to_dot($ip), $timestamp, $email)></span></if></span></if>
	<span class="posticons">
	<if !$parent>
		<if $locked><img src="<var root_path_to_filename('img/locked.png')>" alt="Locked" onmouseover="Tip('<const S_ICONLOCKED>')" onmouseout="UnTip()" /> </if>
		<if $autosage><img src="<var root_path_to_filename('img/autosage.gif')>" alt="<const S_LOCKEDALT>" onmouseover="Tip('<const S_ICONAUTOSAGE>')" onmouseout="UnTip()" /> </if>
	</if>
	<if $banned> <img src="<var root_path_to_filename('img/report.png')>" alt="Banned" onmouseover="Tip('<const S_BANNED>')" onmouseout="UnTip()" /> </if>
	</span>
	<span class="date"><var make_date($timestamp,DATE_STYLE,S_WEEKDAYS,S_MONTHS)></span>
</label>

<span class="reflink">
	<if !$parent>
    	<a href="<var get_reply_link($num,0,$admin)>#i<var $num>">No.<var $num></a>
	<else>
    	<a href="<var get_reply_link($parent,0,$admin)>#i<var $num>">No.<var $num></a>
	</if>
</span>

<if $admin>
	<span>[<var dec_to_dot($ip)>]
		[<a href="<var $self>?task=deleteall&amp;board=<var get_board_id()>&amp;ip=<var $ip>"><const S_MPDELETEALL></a>]
		[<a href="<var $self>?task=addip&amp;board=<var get_board_id()>&amp;type=ipban&amp;ip=<var $ip>&amp;postid=<var $num>" onclick="return do_ban(this)"><const S_MPBAN></a>]
		<if !$parent>
			[<a href="<var $self>?board=<var get_board_id()>&amp;task=lock&amp;thread=<var $num>" title="<const S_MPLOCK>"><if $locked>-</if>L</a>]
			[<a href="<var $self>?board=<var get_board_id()>&amp;task=kontra&amp;thread=<var $num>" title="<const S_MPAUTOSAGE>"><if $autosage>-</if>AS</a>]
		</if>
	</span>
</if>&nbsp;

<if !$parent && !$thread>
	[<a href="<var get_reply_link($num,0,$admin)>"><if !$locked><const S_REPLY><else><const S_VIEW></if></a>]
</if>

<br />

<if $files><div class="file_container"></if>
<loop $files>
    <if $thumbnail><div class="file"></if>
    <if !$thumbnail><div class="file filebg"></if>
	<div class="hidden" id="imageinfo_<var md5_hex($image)>">
		<strong><const S_FILENAME></strong> <var $uploadname><br /><hr />
		<var get_pretty_html($info_all, "\n\t\t")>
	</div>
    <div class="filename"><const S_PICNAME><a target="_blank" title="<var $uploadname>" href="<var expand_image_filename($image)>/<var get_urlstring($uploadname)>"><var $displayname></a></div>
	<div class="filesize"><!--compat for dollscript--><a href="<var expand_image_filename($image)>"></a><var get_displaysize($size, DECIMAL_MARK)><if $width && $height>, <var $width>&nbsp;&times;&nbsp;<var $height></if><if $info>, <var $info></if></div>
    <if $thumbnail>
        <div class="filelink" onmouseover="TagToTip('imageinfo_<var md5_hex($image)>', TITLE, '<const S_FILEINFO>', WIDTH, -450)" onmouseout="UnTip()">
		<a target="_blank" href="<var expand_image_filename($image)>" <if get_extension($image)=~/^JPG|PNG|GIF/>onclick="return expand_image(this, <var $width>, <var $height>, <var $tn_width>, <var $tn_height>, '<var expand_filename($thumbnail)>')"</if>>
			<img src="<var expand_filename($thumbnail)>" width="<var $tn_width>" height="<var $tn_height>" alt="<var $size>" />
		</a>
        </div>
    <else>
		<if !$size>
			<div class="filedeleted"><const S_FILEDELETED></div>
		</if>
		<if $size>
			<if DELETED_THUMBNAIL>
				<a target="_blank" href="<var expand_image_filename(DELETED_IMAGE)>">
					<img src="<var expand_filename(DELETED_THUMBNAIL)>" width="<var $tn_width>" height="<var $tn_height>" alt="" />
				</a>
			</if>
			<if !DELETED_THUMBNAIL>
				<div class="filetype" onmouseover="TagToTip('imageinfo_<var md5_hex($image)>', TITLE, '<const S_FILEINFO>', WIDTH, -450)" onmouseout="UnTip()">
					<a target="_blank" href="<var expand_image_filename($image)>">
						<var get_extension($uploadname)>
					</a>
				</div>
			</if>
		</if>
	</if>
    </div>
</loop>
<if $files></div></if>

<if $abbrev>
    <div class="hidden" id="posttext_full_<var $num>">
        <blockquote><var $comment_full></blockquote>
    </div>
</if>

<div id="posttext_<var $num>"><blockquote>
<var $comment>
<if $abbrev>
	<p class="abbrev">[<a href="<var get_reply_link($num,$parent)>" onclick="return expand_post('<var $num>')"><var $abbrev></a>]</p>
</if>
</blockquote></div>

<if !$parent>
	<if $omitmsg>
    	<span class="omittedposts">
    		<var $omitmsg>
    	</span>
	</if>
	<if !$thread>
		<script type="text/javascript">
			if (hiddenThreads.indexOf('t<var $num>,') != -1)
			{
				toggleHidden('t<var $num>');
			}
		</script>
	</if>
</if>

<if $parent || $single>
	</td></tr></tbody></table>
</if>
};

1;
