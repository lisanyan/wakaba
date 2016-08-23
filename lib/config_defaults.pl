use strict;

BEGIN {
	# use constant S_NOADMIN => 'No ADMIN_PASS or NUKE_PASS defined in the configuration';	# Returns error when the config is incomplete
	use constant S_NOSECRET => 'No SECRET defined in the configuration';		# Returns error when the config is incomplete
	use constant S_NOSQL => 'No SQL settings defined in the configuration';		# Returns error when the config is incomplete

	# die S_NOADMIN unless(defined &ADMIN_PASS);
	# die S_NOADMIN unless(defined &NUKE_PASS);
	die S_NOSECRET unless(defined &SECRET);
	die S_NOSQL unless(defined &SQL_DBI_SOURCE);
	die S_NOSQL unless(defined &SQL_USERNAME);
	die S_NOSQL unless(defined &SQL_PASSWORD);

	eval "use constant SQL_TABLE => 'b_comments'" unless(defined &SQL_TABLE);
	eval "use constant SQL_TABLE_IMG => 'b_img'" unless(defined &SQL_TABLE);
	eval "use constant SQL_ADMIN_TABLE => 'admin'" unless(defined &SQL_ADMIN_TABLE);
	eval "use constant SQL_REPORT_TABLE => 'reports'" unless(defined &SQL_REPORT_TABLE);
	eval "use constant BOARD_IDENT => 'b'" unless(defined &BOARD_IDENT);
	eval "use constant BOARD_LANG => 'en'" unless(defined &BOARD_LANG);

	eval "use constant USE_TEMPFILES => 1" unless(defined &USE_TEMPFILES);

	eval "use constant TITLE => 'Wakab'" unless(defined &TITLE);
	eval "use constant BOARD_NAME => 'Image board'" unless(defined &BOARD_NAME);
	eval "use constant BOARD_DESC => ''" unless(defined &BOARD_DESC);
	eval "use constant BANNER => 0" unless(defined &BANNER);
	eval "use constant FAVICON => '/wakaba.ico'" unless(defined &FAVICON);
	eval "use constant HOME => '../'" unless(defined &HOME);
	eval "use constant IMAGES_PER_PAGE => 10" unless(defined &IMAGES_PER_PAGE);
	eval "use constant REPLIES_PER_THREAD => 4" unless(defined &REPLIES_PER_THREAD);
	eval "use constant IMAGE_REPLIES_PER_THREAD => 0" unless(defined &IMAGE_REPLIES_PER_THREAD);
	eval "use constant REPLIES_PER_LOCKED_THREAD => 1" unless(defined &REPLIES_PER_LOCKED_THREAD);
	eval "use constant IMAGE_REPLIES_PER_LOCKED_THREAD => 0" unless(defined &IMAGE_REPLIES_PER_LOCKED_THREAD);
	eval "use constant S_ANONAME => 'Anonymous'" unless(defined &S_ANONAME);
	eval "use constant S_ANOTEXT => ''" unless(defined &S_ANOTEXT);
	eval "use constant S_ANOTITLE => ''" unless(defined &S_ANOTITLE);
	eval "use constant SILLY_ANONYMOUS => ''" unless(defined &SILLY_ANONYMOUS);
	eval "use constant DEFAULT_STYLE => 'Photon'" unless(defined &DEFAULT_STYLE);

	eval "use constant MAX_KB => 3072" unless(defined &MAX_KB);
	eval "use constant MAX_W => 200" unless(defined &MAX_W);
	eval "use constant MAX_H => 200" unless(defined &MAX_H);
	eval "use constant MAX_RES => 20" unless(defined &MAX_RES);
	eval "use constant MAX_POSTS => 500" unless(defined &MAX_POSTS);
	eval "use constant MAX_THREADS => 0" unless(defined &MAX_THREADS);
	eval "use constant MAX_AGE => 0" unless(defined &MAX_AGE);
	eval "use constant MAX_MEGABYTES => 0" unless(defined &MAX_MEGABYTES);
	eval "use constant MAX_FIELD_LENGTH => 100" unless(defined &MAX_FIELD_LENGTH);
	eval "use constant MAX_COMMENT_LENGTH => 8192" unless(defined &MAX_COMMENT_LENGTH);
	eval "use constant MAX_LINES_SHOWN => 15" unless(defined &MAX_LINES_SHOWN);
	eval "use constant MAX_IMAGE_WIDTH => 16384" unless(defined &MAX_IMAGE_WIDTH);
	eval "use constant MAX_IMAGE_HEIGHT => 16384" unless(defined &MAX_IMAGE_HEIGHT);
	eval "use constant MAX_IMAGE_PIXELS => 50000000" unless(defined &MAX_IMAGE_PIXELS);
    eval "use constant MAX_FILES => 4" unless (defined &MAX_FILES);
	eval "use constant MAX_SEARCH_RESULTS => 200" unless (defined &MAX_SEARCH_RESULTS);
	eval "use constant MAX_STATS => 25" unless (defined &MAX_STATS);

	eval "use constant ENABLE_CAPTCHA => 1" unless(defined &ENABLE_CAPTCHA);
	eval "use constant SQL_CAPTCHA_TABLE => 'captcha'" unless(defined &SQL_CAPTCHA_TABLE);
	eval "use constant CAPTCHA_LIFETIME => 1440" unless(defined &CAPTCHA_LIFETIME);
	eval "use constant CAPTCHA_SCRIPT => '/captcha.pl'" unless(defined &CAPTCHA_SCRIPT);
	eval "use constant CAPTCHA_HEIGHT => 18" unless(defined &CAPTCHA_HEIGHT);
	eval "use constant CAPTCHA_SCRIBBLE => 0.2" unless(defined &CAPTCHA_SCRIBBLE);
	eval "use constant CAPTCHA_SCALING => 0.15" unless(defined &CAPTCHA_SCALING);
	eval "use constant CAPTCHA_ROTATION => 0.3" unless(defined &CAPTCHA_ROTATION);
	eval "use constant CAPTCHA_SPACING => 2.5" unless(defined &CAPTCHA_SPACING);

	eval "use constant ENABLE_REPORTS => 0" unless(defined &ENABLE_REPORTS);
	eval "use constant REPORTS_MAX => 5" unless(defined &REPORTS_MAX);
	eval "use constant REPORTS_REASONLENGTH => 120" unless(defined &REPORTS_REASONLENGTH);

	eval "use constant THUMBNAIL_SMALL => 1" unless(defined &THUMBNAIL_SMALL);
	eval "use constant THUMBNAIL_QUALITY => 70" unless(defined &THUMBNAIL_QUALITY);
	eval "use constant DELETED_THUMBNAIL => ''" unless(defined &DELETED_THUMBNAIL);
	eval "use constant DELETED_IMAGE => ''" unless(defined &DELETED_IMAGE);
	eval "use constant ALLOW_LINK => 0" unless(defined &ALLOW_TEXTONLY);
	eval "use constant ALLOW_TEXTONLY => 1" unless(defined &ALLOW_TEXTONLY);
	eval "use constant ALLOW_IMAGES => 1" unless(defined &ALLOW_IMAGES);
	eval "use constant ALLOW_TEXT_REPLIES => 1" unless(defined &ALLOW_TEXT_REPLIES);
	eval "use constant ALLOW_IMAGE_REPLIES => 1" unless(defined &ALLOW_IMAGE_REPLIES);
	eval "use constant ALLOW_UNKNOWN => 0" unless(defined &ALLOW_UNKNOWN);
	eval "use constant MUNGE_UNKNOWN => '.unknown'" unless(defined &MUNGE_UNKNOWN);
	eval "use constant FORBIDDEN_EXTENSIONS => ('php','php3','php4','phtml','shtml','cgi','pl','pm','py','r','exe','dll','scr','pif','asp','cfm','jsp','rb')" unless(defined &FORBIDDEN_EXTENSIONS);
	eval "use constant RENZOKU => 5" unless(defined &RENZOKU);
	eval "use constant RENZOKU2 => 10" unless(defined &RENZOKU2);
	eval "use constant RENZOKU3 => 900" unless(defined &RENZOKU3);
	eval "use constant RENZOKU4 => 60" unless(defined &RENZOKU4);
	eval "use constant RENZOKU5 => 300" unless(defined &RENZOKU5);
	eval "use constant NOSAGE_WINDOW => 1200" unless(defined &NOSAGE_WINDOW);
	eval "use constant USE_SECURE_ADMIN => 0" unless(defined &USE_SECURE_ADMIN);
	eval "use constant CHARSET => 'utf-8'" unless(defined &CHARSET);
	eval "use constant CONVERT_CHARSETS => 1" unless(defined &CONVERT_CHARSETS);
	eval "use constant TRIM_METHOD => 0" unless(defined &TRIM_METHOD);
	eval "use constant ARCHIVE_MODE => 0" unless(defined &ARCHIVE_MODE);
	eval "use constant DATE_STYLE => 'phutaba-en'" unless(defined &DATE_STYLE);
	eval "use constant DISPLAY_ID => 0" unless(defined &DISPLAY_ID);
	eval "use constant EMAIL_ID => 'Heaven'" unless(defined &EMAIL_ID);
	eval "use constant TRIPKEY => '!'" unless(defined &TRIPKEY);
	eval "use constant DECIMAL_MARK => ','"    unless ( defined &DECIMAL_MARK );
	eval "use constant ENABLE_WAKABAMARK => 1" unless(defined &ENABLE_WAKABAMARK);
	eval "use constant APPROX_LINE_LENGTH => 150" unless(defined &APPROX_LINE_LENGTH);
	eval "use constant STUPID_THUMBNAILING => 0" unless(defined &STUPID_THUMBNAILING);
	eval "use constant ALTERNATE_REDIRECT => 0" unless(defined &ALTERNATE_REDIRECT);
	eval "use constant COOKIE_PATH => 'root'" unless(defined &COOKIE_PATH);
	eval "use constant STYLE_COOKIE => 'wakabastyle'" unless(defined &STYLE_COOKIE);
	eval "use constant FORCED_ANON => 0" unless(defined &FORCED_ANON);
	eval "use constant SPAM_TRAP => 1" unless(defined &SPAM_TRAP);
	eval "use constant PREVENT_GHOST_BUMPING => 1" unless(defined &PREVENT_GHOST_BUMPING);
	eval "use constant ENABLE_AFMOD => 1" unless(defined &ENABLE_AFMOD);

	eval "use constant BAN_DATES => [{label=>'Never',time=>0},{label=>'3 days',time=>3600*24*3},{label=>'1 week',time=>3600*24*7},".
	"{label=>'1 month',time=>3600*24*30},{label=>'1 year',time=>3600*24*365}]" unless(defined &BAN_DATES);

	eval "use constant IMG_DIR => 'src/'" unless(defined &IMG_DIR);
	eval "use constant THUMB_DIR => 'thumb/'" unless(defined &THUMB_DIR);
	eval "use constant RES_DIR => 'res/'" unless(defined &RES_DIR);
	eval "use constant ARCHIVE_DIR => 'arch/'" unless (defined &ARCHIVE_DIR);
    eval "use constant ORPH_DIR => 'orphans/'" unless ( defined &ORPH_DIR );
	eval "use constant HTML_SELF => 'wakaba.html'" unless(defined &HTML_SELF);
	eval "use constant CSS_DIR => 'static/css/'" unless(defined &CSS_DIR);
	eval "use constant PAGE_EXT => '.html'" unless(defined &PAGE_EXT);
	eval "use constant ERRORLOG => ''" unless(defined &ERRORLOG);
	eval "use constant CONVERT_COMMAND => 'convert'" unless(defined &CONVERT_COMMAND);
	eval "use constant VIDEO_CONVERT_COMMAND => 'ffmpeg'" unless(defined &VIDEO_CONVERT_COMMAND);

	eval "use constant FILETYPES => ()" unless(defined &FILETYPES);
	eval "use constant FILESIZES => ()" unless(defined &FILESIZES);
	eval "use constant FILEGROUPS => ()" unless(defined &FILEGROUPS);
	eval "use constant GROUPORDER => ''" unless(defined &GROUPORDER);

	eval "use constant ENABLE_DNSBL_CHECK => 1" unless(defined &ENABLE_DNSBL_CHECK);
	eval "use constant DNSBL_TIMEOUT => 0.1" unless(defined &DNSBL_TIMEOUT);
	eval q{use constant DNSBL_INFOS => []} unless(defined &DNSBL_INFOS);

	eval "use constant WAKABA_VERSION => '3.0.9'" unless(defined &WAKABA_VERSION);
}

1;
