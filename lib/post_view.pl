# post include

use constant POST_VIEW_INCLUDE => q{
    <if !$parent>
    <div id="t<var $num>_info" style="float:left"></div>
    <div id="t<var $num>">
    </if>

    <if $parent>
    <table><tbody><tr><td class="doubledash">&gt;&gt;</td>
    <td class="reply" id="reply<var $num>">
    </if>

    <a id="<var $num>"></a>
    <label><input type="checkbox" name="delete" value="<var $num>" />
    <if !$parent><span class="filetitle"><else><span class="replytitle"></if><var $subject></span>
    <if $email><span class="postername"><a href="<var $email>"><if $adminpost><span class="adminname"><var $name></span><else><var $name></if></a></span><if $trip><span class="postertrip"><a href="<var $email>"><var $trip></a></span></if></if>
    <if !$email><span class="postername"><if $adminpost><span class="adminname"><var $name></span><else><var $name></if></span><if $trip><span class="postertrip"><var $trip></span></if></if>
    <span class="posticons">
    <if !$parent>
    	<if $locked> <img src="<var root_path_to_filename('static/img/locked.png')>" alt="Locked" title="<const S_ICONLOCKED>" /> </if>
    	<if $autosage> <img src="<var root_path_to_filename('static/img/autosage.gif')>" alt="<const S_LOCKEDALT>" title="<const S_ICONAUTOSAGE>" /> </if>
    </if>
    <if $banned> <img src="<var root_path_to_filename('static/img/report.png')>" alt="Banned" title="<const S_BANNED>" /> </if>
    </span>
    <span class="date"><var $date></span></label>
    <span class="reflink">
    <if !$parent>
        <if !$thread><a href="<var get_reply_link($num,0)>#i<var $num>">No.<var $num></a></if>
    <else>
        <if !$thread><a href="<var get_reply_link($parent,0)>#i<var $num>">No.<var $num></a></if>
    </if>
    <if $thread><a href="javascript:insert('&gt;&gt;<var $num>')">No.<var $num></a></if>
    </span>&nbsp;
    <if !$parent && !$thread>[<a href="<var get_reply_link($num,0)>"><const S_REPLY></a>]</if>
    <br />

    <if $image>
        <span class="filesize"><const S_PICNAME><a target="_blank" href="<var expand_image_filename($image)>"><var get_filename($image)></a>
        -(<em><var make_size($size)>, <var $width>x<var $height><if $thread and $origname>, <span title="<var clean_string($origname)>"><var show_filename($origname)></span></if></em>)</span>
        <span class="thumbnailmsg"><const S_THUMB></span><br />

        <if $thumbnail>
            <a target="_blank" href="<var expand_image_filename($image)>">
            <img src="<var expand_filename($thumbnail)>" width="<var $tn_width>" height="<var $tn_height>" alt="<var $size>" class="thumb" /></a>
        </if>
        <if !$thumbnail>
            <if DELETED_THUMBNAIL>
                <a target="_blank" href="<var expand_image_filename(DELETED_IMAGE)>">
                <img src="<var expand_filename(DELETED_THUMBNAIL)>" width="<var $tn_width>" height="<var $tn_height>" alt="" class="thumb" /></a>
            </if>
            <if !DELETED_THUMBNAIL>
                <div class="nothumb"><a target="_blank" href="<var expand_image_filename($image)>"><const S_NOTHUMB></a></div>
            </if>
        </if>
    </if>

    <blockquote>
    <var $comment>
    <if $abbrev><div class="abbrev"><var sprintf(S_ABBRTEXT,get_reply_link($num,$parent))></div></if>
    </blockquote>

    <if !$parent && $omit>
        <span class="omittedposts">
        <if $omitimages><var sprintf S_ABBRIMG,$omit,$omitimages></if>
        <if !$omitimages><var sprintf S_ABBR,$omit></if>
        </span>
    </if>

    <if $parent></td></tr></tbody></table></if>
};

1;
