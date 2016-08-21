use utf8;
use constant S_HOME => 'Home'; # Forwards to home page
use constant S_ADMIN => 'Manage'; # Forwards to Management Panel
use constant S_RETURN => 'Return'; # Returns to image board
use constant S_POSTING => 'Posting mode: Reply'; # Prints message in red bar atop the reply screen
use constant S_BOARD => 'Board';

use constant S_NAME => 'Name'; # Describes name field
use constant S_EMAIL => 'Link'; # Describes e-mail field
use constant S_SUBJECT => 'Subject'; # Describes subject field
use constant S_SUBMIT => 'Submit'; # Describes submit button
use constant S_COMMENT => 'Comment'; # Describes comment field
use constant S_UPLOADFILE => 'File'; # Describes file field
use constant S_NOFILE => 'No File'; # Describes file/no file checkbox
use constant S_CAPTCHA => 'Verification'; # Describes captcha field
use constant S_PARENT => 'Parent'; # Describes parent field on admin post page
use constant S_DELPASS => 'Password'; # Describes password field
use constant S_DELEXPL => '(for post and file deletion)'; # Prints explanation for password box (to the right)
use constant S_SPAMTRAP => 'Leave these fields empty (spam trap): ';
use constant S_SAGE => 'Sage';
use constant S_SAGEDESC => 'Don\'t bump thread';

use constant S_THUMB => ''; #'Thumbnail displayed, click image for full size.';	# Prints instructions for viewing real source
use constant S_HIDDEN => 'Thumbnail hidden, click filename for the full image.'; # Prints instructions for viewing hidden image reply
use constant S_NOTHUMB => 'No<br />thumbnail'; # Printed when there's no thumbnail
use constant S_PICNAME => ''; # Prints text before upload name/link
use constant S_REPLY => 'Reply'; # Prints text for reply link
use constant S_VIEW => 'View'; # Prints text for reply link
use constant S_OLD => 'Marked for deletion (old).'; # Prints text to be displayed before post is marked for deletion, see: retention
use constant S_ABBR => '%d posts omitted. Click Reply to view.'; # Prints text to be shown when replies are hidden
use constant S_ABBRIMG => '%d posts and %d images omitted. Click Reply to view.'; # Prints text to be shown when replies and images are hidden
use constant S_ABBRTEXT => 'Comment too long. Click <a href="%s">here</a> to view the full text.';

use constant S_REPDEL => 'Delete Post '; # Prints text next to S_DELPICONLY (left)
use constant S_DELPICONLY => 'File Only'; # Prints text next to checkbox for file deletion (right)
use constant S_DELKEY => 'Password '; # Prints text next to password field for deletion (left)
use constant S_DELETE => 'Delete'; # Defines deletion button's name
use constant S_REPORT => 'Report'; # Defines report button's name
use constant S_REPORTSUCCESS => 'Thank you for reporting! The staff has been notified and will fix this mess shortly.';

use constant S_PREV => 'Previous'; # Defines previous button
use constant S_FIRSTPG => 'Previous'; # Defines previous button
use constant S_NEXT => 'Next'; # Defines next button
use constant S_LASTPG => 'Next'; # Defines next button

use constant S_SEARCHTITLE => 'Post Search';
use constant S_SEARCH => 'Search';
use constant S_SEARCHCOMMENT => 'In comment';
use constant S_SEARCHSUBJECT => 'In subject';
use constant S_SEARCHFILES => 'In files';
use constant S_SEARCHOP => 'Search in OP only';
use constant S_SEARCHSUBMIT => 'Submit';
use constant S_SEARCHFOUND => 'Found:';
use constant S_OPTIONS => 'Options';
use constant S_MINLENGTH => '(min. 3 symbols)';

use constant S_STATS => 'Stats';
use constant S_STATSTITLE => 'Post Statistics';
use constant S_DATE => 'Date';

use constant S_WEEKDAYS => 'Sun Mon Tue Wed Thu Fri Sat'; # Defines abbreviated weekday names.
use constant S_MONTHS => 'January February March April May June July August September October November December';

use constant S_REPORTHEAD => 'Post reporting';
use constant S_REPORTEXPL => 'You are reporting the following posts:';
use constant S_REPORTREASON => 'Please enter a report reason:';

# javascript message strings (do not use HTML entities; mask single quotes with \\\')
use constant S_JS_REMOVEFILE => 'Remove file';
use constant S_JS_SHOWTHREAD => 'Show Thread (+)';
use constant S_JS_HIDETHREAD => 'Hide Thread (\u2212)';
use constant S_HIDETHREAD => 'Hide Thread (&minus;)';
# javascript strings END

use constant S_MANARET => 'Return'; # Returns to HTML file instead of PHP--thus no log/SQLDB update occurs
use constant S_MANAMODE => 'Manager Mode'; # Prints heading on top of Manager page

use constant S_MANALOGIN => 'Manager Login'; # Defines Management Panel radio button--allows the user to view the management panel (overview of all posts)
use constant S_ADMINPASS => 'Admin password:'; # Prints login prompt

use constant S_MANAPANEL => 'Management Panel'; # Defines Management Panel radio button--allows the user to view the management panel (overview of all posts)
use constant S_MANABANS => 'Bans/Whitelist'; # Defines Bans Panel button
use constant S_MANAPOST => 'Manager Post'; # Defines Manager Post radio button--allows the user to post using HTML code in the comment box
use constant S_MANAREPORTS => 'Post Reports';
use constant S_MANAREBUILD => 'Rebuild caches';							#
use constant S_MANALOGOUT => 'Log out';									#
use constant S_MANASAVE => 'Remember me on this computer'; # Defines Label for the login cookie checbox
use constant S_MANASUB => 'Go'; # Defines name for submit button in Manager Mode
use constant S_MANAORPH => 'Orphans';
use constant S_MANASHOW => 'Show';

use constant S_NOTAGS => 'HTML tags allowed. No formatting will be done, you must use HTML for line breaks and paragraphs.'; # Prints message on Management Board
use constant S_NOTAGS2 => 'No format.'; # Prints message on Management Board
use constant S_POSTASADMIN => 'Post as admin';

use constant S_REPORTSNUM => 'Post No.';
use constant S_REPORTSBOARD => 'Board';
use constant S_REPORTSDATE => 'Date &amp; Time';
use constant S_REPORTSCOMMENT => 'Comment';
use constant S_REPORTSIP => 'IP';
use constant S_REPORTSDISMISS => 'Dismiss';

use constant S_MPDELETEIP => 'Delete all';
use constant S_MPDELETE => 'Delete'; # Defines for deletion button in Management Panel
use constant S_MPARCHIVE => 'Archive';
use constant S_MPRESET => 'Reset'; # Defines name for field reset button in Management Panel
use constant S_MPONLYPIC => 'File Only'; # Sets whether or not to delete only file, or entire post/thread
use constant S_MPDELETEALL => 'Del&nbsp;all';							#
use constant S_MPBAN => 'Ban';											#
use constant S_MPLOCK => 'Lock';
use constant S_MPAUTOSAGE => 'Autosage';
use constant S_IMGSPACEUSAGE => '[ Space used: %s ]'; # Prints space used KB by the board under Management Panel
use constant S_DELALLMSG => 'Affected';
use constant S_DELALLCOUNT => '%s Posts (%s Threads)';
use constant S_ALLOWED => 'Allowed file types (Max: %s)';

use constant S_ABBR1 => '1 Post '; # Prints text to be shown when replies are hidden
use constant S_ABBR2 => '%d Posts ';
use constant S_ABBRIMG1 => 'and 1 File '; # Prints text to be shown when replies and files are hidden
use constant S_ABBRIMG2 => 'and %d Files ';
use constant S_ABBR_END => 'hidden.';

use constant S_ABBRTEXT1 => 'One more line';
use constant S_ABBRTEXT2 => '%d more lines';

use constant S_BANTABLE => '<th>Type</th><th>Date</th><th>Expires</th>'
                            .'<th colspan="2">Value</th><th>Comment</th><th>Action</th>'; # Explains names for Ban Panel
use constant S_BANIPLABEL => 'IP';
use constant S_BANMASKLABEL => 'Mask';
use constant S_BANCOMMENTLABEL => 'Comment';
use constant S_BANEXPIRESLABEL => 'Expires';
use constant S_BANWORDLABEL => 'Word';
use constant S_BANIP => 'Ban IP';
use constant S_BANWORD => 'Ban word';
use constant S_BANWHITELIST => 'Whitelist';
use constant S_BANREMOVE => 'Remove';
use constant S_BANCOMMENT => 'Comment';
use constant S_BANTRUST => 'No captcha';
use constant S_BANTRUSTTRIP => 'Tripcode';
use constant S_BANSECONDS => '(seconds)';
use constant S_BANEXPIRESNEVER => 'Never';

use constant S_BADIP => 'Bad IP value';

use constant S_TOOBIG => 'This image is too large!  Upload something smaller!';
use constant S_TOOBIGORNONE => 'Either this image is too big or there is no image at all.  Yeah.';
use constant S_REPORTERR => 'Cannot find reply.'; # Returns error when a reply (res) cannot be found
use constant S_UPFAIL => 'Upload failed.'; # Returns error for failed upload (reason: unknown?)
use constant S_NOREC => 'Cannot find record.'; # Returns error when record cannot be found
use constant S_NOCAPTCHA => 'No verification code on record - it probably timed out.'; # Returns error when there's no captcha in the database for this IP/key
use constant S_BADCAPTCHA => 'Wrong verification code entered.'; # Returns error when the captcha is wrong
use constant S_BADFORMAT => 'File format not supported.'; # Returns error when the file is not in a supported format.
use constant S_STRREF => 'String refused.'; # Returns error when a string is refused
use constant S_UNJUST => 'Unjust POST.'; # Returns error on an unjust POST - prevents floodbots or ways not using POST method?
use constant S_NOPIC => 'No file selected. Did you forget to click "Reply"?'; # Returns error for no file selected and override unchecked
use constant S_NOTEXT => 'No comment entered.'; # Returns error for no text entered in to subject/comment
use constant S_TOOLONG => 'Too many characters in text field.'; # Returns error for too many characters in a given field
use constant S_NOTALLOWED => 'Posting not allowed.'; # Returns error for non-allowed post types
use constant S_UNUSUAL => 'Abnormal reply.'; # Returns error for abnormal reply? (this is a mystery!)
use constant S_BADHOST => 'Host is banned.'; # Returns error for banned host ($badip string)
use constant S_BADHOSTPROXY => 'Proxy is banned for being open.'; # Returns error for banned proxy ($badip string)
use constant S_RENZOKU => 'Flood detected, post discarded.'; # Returns error for $sec/post spam filter
use constant S_RENZOKU2 => 'Flood detected, file discarded.'; # Returns error for $sec/upload spam filter
use constant S_RENZOKU3 => 'Flood detected.'; # Returns error for $sec/similar posts spam filter.
use constant S_DUPE => 'This file has already been posted <a href="%s">here</a>.'; # Returns error when an md5 checksum already exists.
use constant S_DUPENAME => 'A file with the same name already exists.'; # Returns error when an filename already exists.
use constant S_NOPOSTS => 'You didn\'t select any posts!';
use constant S_CANNOTREPORT => 'You cannot report posts on this board.';
use constant S_REPORTSFLOOD => 'You can only report up to %d posts.';
use constant S_NOTHREADERR => 'Thread does not exist.'; # Returns error when a non-existant thread is accessed
use constant S_BADDELPASS => 'Incorrect password for deletion.'; # Returns error for wrong password (when user tries to delete file)
use constant S_BADDELIP => 'Wrong ip';
use constant S_NOTEXISTPOST => 'The post %d does not exist.';
use constant S_WRONGPASS => 'Management password incorrect.'; # Returns error for wrong password (when trying to access Manager modes)
use constant S_VIRUS => 'Possible virus-infected file.'; # Returns error for malformed files suspected of being virus-infected.
use constant S_NOTWRITE => 'Could not write to directory.'; # Returns error when the script cannot write to the directory, the chmod (777) is wrong
use constant S_SPAM => 'Spammers are not welcome here.'; # Returns error when detecting spam
use constant S_LOCKED => 'Thread is closed.';
use constant S_NOBOARDACC => 'You don\'t have access to this board, accessible: %s<br /><a href="%s?task=logout">Logout</a>';
use constant S_PREWRAP => '<span class="prewrap">%s</span>';

use constant S_THREADLOCKED => '<strong>Thread %s</strong> is locked. You cannot reply to this thread.';
use constant S_FILEINFO => 'Information';
use constant S_FILEDELETED => 'File deleted';
use constant S_FILENAME => 'File Name:';

use constant S_ICONAUTOSAGE => 'Bumplimit';
use constant S_ICONLOCKED => 'Closed';
use constant S_BANNED => 'User was banned for this post';

use constant S_SQLCONF => 'SQL connection failure'; # Database connection failure
use constant S_SQLFAIL => 'Critical SQL problem!'; # SQL Failure

use constant S_DNSBL => 'This IP was listed in <em>%s</em> blacklist!'; # error string for tor node check
use constant S_AUTOBAN => 'Spambot [Auto Ban]'; # Ban reason for automatically created bans

use constant S_REDIR => 'If the redirect didn\'t work, please choose one of the following mirrors:'; # Redir message for html in REDIR_DIR

1;
