#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;

use CGI;
use DBI;
use JSON::XS;

#
# Import settings
#

use lib '.';
my $query;

BEGIN
{
	$query = CGI->new;

	my $board=$query->param("board");
	# todo: this will be replaced by a global list of boards
	$board =~ s/[\*<>|?&]//g; # remove special characters
 	$board =~ s/.*[\\\/]//; # remove any leading path

	if (!$board)
	{
		print "Content-Type: text/plain\n\n";
		print "Missing board parameter.\n";
		exit;
	}

	if (!-d $board or !-f $board . "/config.pl") {
		print "Content-Type: text/plain\n\n";
		print "\nUnknown board.\n";
		exit;
	}

	require $board."/config.pl";;

	sub get_board_id { $board };
}

BEGIN
{
	require "lib/site_config.pl";
	require "lib/config_defaults.pl";
	require "lib/strings_en.pl";	# edit this line to change the language
	require "lib/futaba_style.pl";	# edit this line to change the board style
	require "captcha.pl";
	require "lib/wakautils.pl";
}

#
# Optional modules
#

my ($has_encode);

if(CONVERT_CHARSETS)
{
	eval 'use Encode qw(decode encode)';
	$has_encode=1 unless($@);
}

my $JSON = JSON::XS->new->pretty; #->utf8

#
# Global init
#

my $protocol_re=qr/(?:http|https|ftp|mailto|nntp)/;

my ($dbh, $ajax_errors);
$dbh=DBI->connect(SQL_DBI_SOURCE,SQL_USERNAME,SQL_PASSWORD,{AutoCommit=>1}) or make_error($DBI::errstr);

return 1 if(caller); # stop here if we're being called externally

# init
{
	# my $query=new CGI;
	my $kotyatki = $dbh->prepare("SET NAMES 'utf8';") or make_error(S_SQLFAIL);
	$kotyatki->execute() or make_error("SQL: Failed to set names");
	$kotyatki->finish();

	my $task=($query->param("task") or $query->param("action"));
	my $json  = ( $query->param("json") or "" );

	# check for admin table
	init_admin_database() if(!table_exists(SQL_ADMIN_TABLE));

	# check for proxy table
	init_proxy_database() if(!table_exists(SQL_PROXY_TABLE));

	if ( $json eq "post" ) {
		my $id = $query->param("id");
		if ( defined($id) and $id =~ /^[+-]?\d+$/ ) {
			output_json_post($id);
		}
		else { make_json_error(''); }
	}
	elsif ( $json eq "newposts" ) {
		my $id = $query->param("id");
		my $after = $query->param("after");
		if ( defined($after) and $after =~ /^[+-]?\d+$/ and $id =~ /^[+-]?\d+$/ ) {
			output_json_newposts($after, $id);
		}
		else { make_json_error(''); }
	}
	elsif ( $json eq "postcount" ) {
		my $id = $query->param("id");
		if ( defined($id) and $id =~ /^[+-]?\d+$/ ) {
			output_json_postcount($id);
		}
		else { make_json_error(''); }
	}
	elsif ( $json eq "checkconfig" ) {
		my $captcha_only = $query->param("captcha");
		get_boardconfig($captcha_only, 1);
	}
	elsif ( $json ) {
		make_json_error();
	}

	if(!table_exists(SQL_TABLE)) # check for comments table
	{
		init_database();
		build_cache();
		make_http_forward(get_board_id().'/'.HTML_SELF,ALTERNATE_REDIRECT);
	}
	elsif(!$task and !$json)
	{
		my $hself = get_board_id().'/'.HTML_SELF;
		build_cache() unless -e $hself;
		make_http_forward($hself,ALTERNATE_REDIRECT);
	}
	elsif($task eq "post")
	{
		my $parent=$query->param("parent");
		my $spam1=$query->param("name");
		my $spam2=$query->param("link");
		my $name=$query->param("field1");
		my $email=$query->param("field2");
		my $subject=$query->param("field3");
		my $comment=$query->param("field4");
		my $file=$query->param("file");
		my $password=$query->param("password");
		my $nofile=$query->param("nofile");
		my $captcha=$query->param("captcha");
		my $admin=$query->param("admin");
		my $no_captcha=$query->param("no_captcha");
		my $no_format=$query->param("no_format");
		my $postfix=$query->param("postfix");
		my $ajax=$query->param("ajax");

		post_stuff(
			$parent,$spam1,$spam2,$name,$email,
			$subject,$comment,$file,$file,$password,
			$nofile,$captcha,$admin,$no_captcha,$no_format,
			$postfix,$ajax
		);
	}
	elsif($task eq "delete")
	{
		my $password=$query->param("password");
		my $fileonly=$query->param("fileonly");
		my $archive=$query->param("archive");
		my $admin=$query->param("admin");
		my $ajax=$query->param("ajax");
		my @posts=$query->param("delete");

		delete_stuff($password,$fileonly,$archive,$admin,$ajax,@posts);
	}
	elsif($task eq "admin")
	{
		my $password=$query->param("berra"); # lol obfuscation
		my $nexttask=$query->param("nexttask");
		my $savelogin=$query->param("savelogin");
		my $admincookie=$query->cookie("wakaadmin");

		do_login($password,$nexttask,$savelogin,$admincookie);
	}
	elsif($task eq "logout")
	{
		do_logout();
	}
	elsif($task eq "mpanel")
	{
		my $admin=$query->param("admin");
		make_admin_post_panel($admin);
	}
	elsif($task eq "deleteall")
	{
		my $admin=$query->param("admin");
		my $ip=$query->param("ip");
		my $mask=$query->param("mask");
		delete_all($admin,parse_range($ip,$mask));
	}
	elsif($task eq "bans")
	{
		my $admin=$query->param("admin");
		make_admin_ban_panel($admin);
	}
	elsif($task eq "addip")
	{
		my $admin=$query->param("admin");
		my $type=$query->param("type");
		my $comment=$query->param("comment");
		my $ip=$query->param("ip");
		my $mask=$query->param("mask");
		add_admin_entry($admin,$type,$comment,parse_range($ip,$mask),'');
	}
	elsif($task eq "addstring")
	{
		my $admin=$query->param("admin");
		my $type=$query->param("type");
		my $string=$query->param("string");
		my $comment=$query->param("comment");
		add_admin_entry($admin,$type,$comment,0,0,$string);
	}
	elsif($task eq "removeban")
	{
		my $admin=$query->param("admin");
		my $num=$query->param("num");
		remove_admin_entry($admin,$num);
	}
	elsif($task eq "mpost")
	{
		my $admin=$query->param("admin");
		make_admin_post($admin);
	}
	elsif($task eq "rebuild")
	{
		my $admin=$query->param("admin");
		do_rebuild_cache($admin);
	}
	else
	{
		make_error("Invalid task!") if !$json;
	}

	$dbh->disconnect();
}

#
# Cache page creation
#

sub build_cache()
{
	my ($sth,$row,@thread);
	my $page=0;

	# grab all posts, in thread order (ugh, ugly kludge)
	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." ORDER BY lasthit DESC,CASE parent WHEN 0 THEN num ELSE parent END ASC,num ASC") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	$row=get_decoded_hashref($sth);
	hide_row_els($row) if $row;

	if(!$row) # no posts on the board!
	{
		build_cache_page(0,1); # make an empty page 0
	}
	else
	{
		my @threads;
		my @thread=($row);

		while($row=get_decoded_hashref($sth))
		{
			hide_row_els($row);
			if(!$$row{parent})
			{
				push @threads,{posts=>[@thread]};
				@thread=($row); # start new thread
			}
			else
			{
				push @thread,$row;
			}
		}
		push @threads,{posts=>[@thread]};

		my $total=get_page_count(scalar @threads);
		my @pagethreads;
		while(@pagethreads=splice @threads,0,IMAGES_PER_PAGE)
		{
			build_cache_page($page,$total,@pagethreads);
			$page++;
		}
	}

	# check for and remove old pages
	while(-e $page.PAGE_EXT)
	{
		unlink get_board_id().'/'.$page.PAGE_EXT;
		unlink get_board_id().'/'.$page.".json";
		$page++;
	}
}

sub build_cache_page($$@)
{
	my ($page,$total,@threads)=@_;
	my ($filename,$tmpname);

	if($page==0) { $filename=get_board_id().'/'.HTML_SELF; }
	else { $filename=get_board_id().'/'.$page.PAGE_EXT; }

	# do abbrevations and such
	foreach my $thread (@threads)
	{
		# split off the parent post, and count the replies and images
		my ($parent,@replies)=@{$$thread{posts}};
		my $replies=@replies;
		my $images=grep { $$_{image} } @replies;
		my $curr_replies=$replies;
		my $curr_images=$images;
		my $max_replies=REPLIES_PER_THREAD;
		my $max_images=(IMAGE_REPLIES_PER_THREAD or $images);

		# drop replies until we have few enough replies and images
		while($curr_replies>$max_replies or $curr_images>$max_images)
		{
			my $post=shift @replies;
			$curr_images-- if($$post{image});
			$curr_replies--;
		}

		# write the shortened list of replies back
		$$thread{posts}=[$parent,@replies];
		$$thread{omit}=$replies-$curr_replies;
		$$thread{omitimages}=$images-$curr_images;

		# abbreviate the remaining posts
		foreach my $post (@{$$thread{posts}})
		{
			my $abbreviation=abbreviate_html($$post{comment},MAX_LINES_SHOWN,APPROX_LINE_LENGTH);
			if($abbreviation)
			{
				$$post{comment}=$abbreviation;
				$$post{abbrev}=1;
			}
		}
	}

	# make the list of pages
	my @pages=map +{ page=>$_ },(0..$total-1);
	foreach my $p (@pages)
	{
		if($$p{page}==0) { $$p{filename}=expand_filename(HTML_SELF) } # first page
		else { $$p{filename}=expand_filename($$p{page}.PAGE_EXT) }
		if($$p{page}==$page) { $$p{current}=1 } # current page, no link
	}

	my ($prevpage,$nextpage);
	$prevpage=$pages[$page-1]{filename} if($page!=0);
	$nextpage=$pages[$page+1]{filename} if($page!=$total-1);

	print_page($filename,PAGE_TEMPLATE->(
		postform=>(ALLOW_TEXTONLY or ALLOW_IMAGES),
		image_inp=>ALLOW_IMAGES,
		textonly_inp=>(ALLOW_IMAGES and ALLOW_TEXTONLY),
		prevpage=>$prevpage,
		nextpage=>$nextpage,
		pages=>\@pages,
		threads=>\@threads
	));

	# JSON
	my %json = (
        boardinfo => get_boardconfig(),
        pages => \@pages,
        data => \@threads
    );

	if($filename eq get_board_id().'/'.HTML_SELF){
		my $output = $JSON->encode(\%json);
		print_page(get_board_id().'/'."0.json",$output);
	}
	else{
		my $output = $JSON->encode(\%json);
		print_page(get_board_id().'/'.substr($filename,0,-4)."json",$output);
	}
}

sub build_thread_cache($)
{
	my ($thread)=@_;
	my ($sth,$row,@thread);
	my ($filename,$tmpname);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=? OR parent=? ORDER BY num ASC;") or make_error(S_SQLFAIL);
	$sth->execute($thread,$thread) or make_error(S_SQLFAIL);

	while($row=get_decoded_hashref($sth))
	{
		hide_row_els($row);
		push(@thread,$row);
	}

	make_error(S_NOTHREADERR) if($thread[0]{parent});

	$filename=get_board_id().'/'.RES_DIR.$thread.PAGE_EXT;

	print_page($filename,PAGE_TEMPLATE->(
		thread=>$thread,
		postform=>(ALLOW_TEXT_REPLIES or ALLOW_IMAGE_REPLIES),
		image_inp=>ALLOW_IMAGE_REPLIES,
		textonly_inp=>0,
		dummy=>$thread[$#thread]{num},
		threads=>[{posts=>\@thread}])
	);

	# now build the json file
	$filename=get_board_id().'/'.RES_DIR.$thread.".json";

	my %json = (
        boardinfo => get_boardconfig(),
        data => [{posts=>\@thread}],
    );
	my $output = $JSON->encode(\%json);

	print_page($filename,$output);
}

sub print_page($$)
{
	my ($filename,$contents)=@_;

	$contents=encode_string($contents);
#		$PerlIO::encoding::fallback=0x0200 if($has_encode);
#		binmode PAGE,':encoding('.CHARSET.')' if($has_encode);

	if(USE_TEMPFILES)
	{
		my $tmpname=get_board_id().'/'.RES_DIR.'tmp'.int(rand(1000000000));

		open (PAGE,">$tmpname") or make_error(S_NOTWRITE);
		print PAGE $contents;
		close PAGE;

		rename $tmpname,$filename;
	}
	else
	{
		open (PAGE,">$filename") or make_error(S_NOTWRITE);
		print PAGE $contents;
		close PAGE;
	}
}

sub build_thread_cache_all()
{
	my ($sth,$row,@thread);

	$sth=$dbh->prepare("SELECT num FROM ".SQL_TABLE." WHERE parent=0;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	while($row=$sth->fetchrow_arrayref())
	{
		build_thread_cache($$row[0]);
	}
}

sub hide_row_els {
    my ($row) = @_;
	# bububu
    delete @$row {'password', 'ip'};
}

#
# JSON stuff
#

sub output_json_post {
    my ($id) = @_;
    my ($sth, $row, $error, $code, %status, %data, %json);
    $ajax_errors = 1;

    $sth = $dbh->prepare("SELECT * FROM " . SQL_TABLE . " WHERE num=?;") or make_error(S_SQLFAIL);
    $sth->execute($id) or make_error(S_SQLFAIL);
    $error = $sth->errstr;
    $row = get_decoded_hashref($sth);

    if( defined($row) ) {
        $code = 200;
        hide_row_els($row);
        $data{'post'} = $row;
    }
    elsif($sth->rows == 0) {
        $code = 404;
        $error = 'Element not found.';
    }
    else {
        $code = 500;
    }

    %status = (
        error_code => $code,
        error_msg => $error,
    );
    %json = (
        data => \%data,
        status => \%status,
    );
    $sth->finish();

    make_json_header();
    print $JSON->encode(\%json);
}

sub output_json_newposts {
    my ($after, $id) = @_;
    my ($sth, $row, $error, $code, %status, @data, %json);
    $ajax_errors = 1;

    $sth = $dbh->prepare("SELECT * FROM " . SQL_TABLE . " WHERE parent=? and num>? ORDER BY num ASC;") or make_error(S_SQLFAIL);
    $sth->execute($id,$after) or make_error(S_SQLFAIL);
    $error = $sth->errstr;

    if($sth->rows) {
        $code = 200;
        while( $row=get_decoded_hashref($sth) ) {
            hide_row_els($row);
            push(@data, $row);
        }
    }
    elsif($sth->rows == 0) {
        $code = 404;
        $error = 'Element not found.';
    }
    else {
        $code = 500;
    }

    %status = (
        error_code => $code,
        error_msg => $error,
    );
    %json = (
        data => \@data,
        status => \%status,
    );
    $sth->finish();

    make_json_header();
    print $JSON->encode(\%json);
}

sub output_json_postcount {
    my ($id) = @_;
    my ($sth, $row, $error, $code, %status, %json);
    $ajax_errors = 1;

    my $exists = thread_exists($id);
    if($exists) {
        $sth = $dbh->prepare("SELECT count(`num`) AS postcount FROM " . SQL_TABLE . " WHERE parent=? OR num=? ORDER BY num ASC;") or make_error(S_SQLFAIL);
        $sth->execute($id, $id) or make_error(S_SQLFAIL);

        $error = decode(CHARSET, $sth->errstr);
        $row = get_decoded_hashref($sth);

        $sth->finish;
    }

    if( defined($row) ) {
        $code = 200;
    }
    elsif(!$exists) {
        $code = 404;
        $error = 'Element not found.';
    }
    else {
        $code = 500;
    }

    %status = (
        error_code => $code,
        error_msg => $error,
    );

    %json = (
        data => $row,
        status => \%status
    );

    make_json_header();
    print $JSON->encode(\%json);
}

sub get_boardconfig {
    my ($captcha_only, $standalone) = @_;
    my %result;

    my %boardinfo = (
        board_title => TITLE,
        config => {
            names_allowed => !FORCED_ANON,
            posting_allowed => (ALLOW_TEXT_REPLIES or ALLOW_IMAGE_REPLIES),
            image_replies => ALLOW_IMAGE_REPLIES,
            image_op => ALLOW_IMAGES,
            max_res => MAX_RES,
            max_field_length => MAX_FIELD_LENGTH,
            max_comment_bytesize => MAX_COMMENT_LENGTH,
            default_name => S_ANONAME,
            captcha => ENABLE_CAPTCHA,
        }
    );
    return \%boardinfo unless $standalone;

    make_json_header();
    if(defined $captcha_only) {
        %result = ( captcha => $boardinfo{'config'}->{captcha} );
    } else {
        %result = ( %boardinfo );
    }
    print $JSON->encode(\%result);
}

#
# Posting
#

sub post_stuff
{
	my (
		$parent,$spam1,$spam2,$name,$email,
		$subject,$comment,$file,$uploadname,$password,
		$nofile,$captcha,$admin,$no_captcha,$no_format,
		$postfix,$ajax
	)=@_;

	# get a timestamp for future use
	my $time=time();

	$ajax_errors=1 if $ajax;

	# check that the request came in as a POST, or from the command line
	make_error(S_UNJUST) if($ENV{REQUEST_METHOD} and $ENV{REQUEST_METHOD} ne "POST");

	if($admin) # check admin password - allow both encrypted and non-encrypted
	{
		check_password($admin,ADMIN_PASS);
	}
	else
	{
		# forbid admin-only features
		make_error(S_WRONGPASS) if($no_captcha or $no_format or $postfix);

		# check what kind of posting is allowed
		if($parent)
		{
			make_error(S_NOTALLOWED) if($file and !ALLOW_IMAGE_REPLIES);
			make_error(S_NOTALLOWED) if(!$file and !ALLOW_TEXT_REPLIES);
		}
		else
		{
			make_error(S_NOTALLOWED) if($file and !ALLOW_IMAGES);
			make_error(S_NOTALLOWED) if(!$file and !ALLOW_TEXTONLY);
		}
	}

	# check for weird characters
	make_error(S_UNUSUAL) if($parent=~/[^0-9]/);
	make_error(S_UNUSUAL) if(length($parent)>10);
	make_error(S_UNUSUAL) if($name=~/[\n\r]/);
	make_error(S_UNUSUAL) if($email=~/[\n\r]/);
	make_error(S_UNUSUAL) if($subject=~/[\n\r]/);

	# check for excessive amounts of text
	make_error(S_TOOLONG) if(length($name)>MAX_FIELD_LENGTH);
	make_error(S_TOOLONG) if(length($email)>MAX_FIELD_LENGTH);
	make_error(S_TOOLONG) if(length($subject)>MAX_FIELD_LENGTH);
	make_error(S_TOOLONG) if(length($comment)>MAX_COMMENT_LENGTH);

	# check to make sure the user selected a file, or clicked the checkbox
	make_error(S_NOPIC) if(!$parent and !$file and !$nofile and !$admin);

	# check for empty reply or empty text-only post
	make_error(S_NOTEXT) if($comment=~/^\s*$/ and !$file);

	# get file size, and check for limitations.
	my $size=get_file_size($file) if($file);

	# find IP
	my $ip=$ENV{REMOTE_ADDR};

	#$host = gethostbyaddr($ip);
	my $numip=dot_to_dec($ip);

	# set up cookies
	my $c_name=$name;
	my $c_email=$email;
	my $c_password=$password;

	# check if IP is whitelisted
	my $whitelisted=is_whitelisted($numip);

	# process the tripcode - maybe the string should be decoded later
	my $trip;
	($name,$trip)=process_tripcode($name,TRIPKEY,SECRET,CHARSET);

	# check for bans
	ban_check($numip,$c_name,$subject,$comment) unless $whitelisted;

	# check for spam trap fields
	if ($spam1 or $spam2) {
		my ($banip, $banmask) = parse_range($numip, '');

		my $sth = $dbh->prepare(
			"INSERT INTO " . SQL_ADMIN_TABLE . " VALUES(null,?,?,?,?,null);")
		  or make_error(S_SQLFAIL);
		$sth->execute('ipban', S_AUTOBAN, $banip, $banmask)
		  or make_error(S_SQLFAIL);

		make_error(S_SPAM);
	}

	# check captcha
	check_captcha($dbh,$captcha,$ip,$parent,get_board_id()) if(ENABLE_CAPTCHA and !$no_captcha and !is_trusted($trip));

	# check if thread exists, and get lasthit value
	my ($parent_res,$lasthit);
	if($parent)
	{
		$parent_res=get_parent_post($parent) or make_error(S_NOTHREADERR);
		$lasthit=$$parent_res{lasthit};
	}
	else
	{
		$lasthit=$time;
	}


	# kill the name if anonymous posting is being enforced
	if(FORCED_ANON)
	{
		$name='';
		$trip='';
		if($email=~/sage/i) { $email='sage'; }
		else { $email=''; }
	}

	# clean up the inputs
	$email=clean_string(decode_string($email,CHARSET));
	$subject=clean_string(decode_string($subject,CHARSET));

	# fix up the email/link
	$email="mailto:$email" if $email and $email!~/^$protocol_re:/;

	# format comment
	$comment=format_comment(clean_string(decode_string($comment,CHARSET))) unless $no_format;
	$comment.=$postfix;

	# insert default values for empty fields
	$parent=0 unless $parent;
	$name=make_anonymous($ip,$time) unless $name or $trip;
	$subject=S_ANOTITLE unless $subject;
	$comment=S_ANOTEXT unless $comment;

	# flood protection - must happen after inputs have been cleaned up
	flood_check($numip,$time,$comment,$file);

	# Manager and deletion stuff - duuuuuh?

	# generate date
	my $date=make_date($time,DATE_STYLE);

	# generate ID code if enabled
	$date.=' ID:'.make_id_code($ip,$time,$email) if(DISPLAY_ID);

	# copy file, do checksums, make thumbnail, etc
	my ($filename,$md5,$width,$height,$thumbnail,$tn_width,$tn_height)=process_file($file,$uploadname,$time) if($file);

	# finally, write to the database
	my $sth=$dbh->prepare("INSERT INTO ".SQL_TABLE." VALUES(null,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);") or make_error(S_SQLFAIL);
	$sth->execute($parent,$time,$lasthit,$numip,
	$date,$name,$trip,$email,$subject,$password,$comment,
	$filename,$size,$md5,$width,$height,$thumbnail,$tn_width,$tn_height) or make_error(S_SQLFAIL);

	if($parent) # bumping
	{
		# check for sage, or too many replies
		unless($email=~/sage/i or sage_count($parent_res)>MAX_RES)
		{
			$sth=$dbh->prepare("UPDATE ".SQL_TABLE." SET lasthit=$time WHERE num=? OR parent=?;") or make_error(S_SQLFAIL);
			$sth->execute($parent,$parent) or make_error(S_SQLFAIL);
		}
	}

	# remove old threads from the database
	trim_database();

	# update the cached HTML pages
	build_cache();

	# find out what our new thread number is
	if($filename)
	{
		$sth=$dbh->prepare("SELECT num FROM ".SQL_TABLE." WHERE timestamp=? AND image=?;") or make_error(S_SQLFAIL);
		$sth->execute($time,$filename) or make_error(S_SQLFAIL);
	}
	else
	{
		$sth=$dbh->prepare("SELECT num FROM ".SQL_TABLE." WHERE timestamp=? AND comment=?;") or make_error(S_SQLFAIL);
		$sth->execute($time,$comment) or make_error(S_SQLFAIL);
	}
	my $num=($sth->fetchrow_array())[0];

	# update the individual thread cache
	if($parent) { build_thread_cache($parent); }
	elsif($num) { build_thread_cache($num); }

	# set the name, email and password cookies
	make_cookies(name=>$c_name,email=>$c_email,password=>$c_password,
	-charset=>CHARSET,-autopath=>COOKIE_PATH); # yum!

	if(!$ajax) {
		# redirect to the appropriate page
		if($parent) { make_http_forward(get_board_id().'/'.RES_DIR.$parent.PAGE_EXT.($num?"#$num":""), ALTERNATE_REDIRECT); }
		elsif($num)	{ make_http_forward(get_board_id().'/'.RES_DIR.$num.PAGE_EXT, ALTERNATE_REDIRECT); }
		else { make_http_forward(get_board_id().'/'.HTML_SELF,ALTERNATE_REDIRECT); } # shouldn't happen
	}
    else {
        make_json_header();
        print $JSON->encode({
            parent => $parent,
            num => $num,
        });
    }
}

sub is_whitelisted($)
{
	my ($numip)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_ADMIN_TABLE." WHERE type='whitelist' AND ? & ival2 = ival1 & ival2;") or make_error(S_SQLFAIL);
	$sth->execute($numip) or make_error(S_SQLFAIL);

	return 1 if(($sth->fetchrow_array())[0]);

	return 0;
}

sub is_trusted($)
{
	my ($trip)=@_;
	my ($sth);
        $sth=$dbh->prepare("SELECT count(*) FROM ".SQL_ADMIN_TABLE." WHERE type='trust' AND sval1 = ?;") or make_error(S_SQLFAIL);
        $sth->execute($trip) or make_error(S_SQLFAIL);

        return 1 if(($sth->fetchrow_array())[0]);

	return 0;
}

sub ban_check($$$$)
{
	my ($numip,$name,$subject,$comment)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_ADMIN_TABLE." WHERE type='ipban' AND ? & ival2 = ival1 & ival2;") or make_error(S_SQLFAIL);
	$sth->execute($numip) or make_error(S_SQLFAIL);

	make_error(S_BADHOST) if(($sth->fetchrow_array())[0]);

# fucking mysql...
#	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_ADMIN_TABLE." WHERE type='wordban' AND ? LIKE '%' || sval1 || '%';") or make_error(S_SQLFAIL);
#	$sth->execute($comment) or make_error(S_SQLFAIL);
#
#	make_error(S_STRREF) if(($sth->fetchrow_array())[0]);

	$sth=$dbh->prepare("SELECT sval1 FROM ".SQL_ADMIN_TABLE." WHERE type='wordban';") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	my $row;
	while($row=$sth->fetchrow_arrayref())
	{
		my $regexp=quotemeta $$row[0];
		make_error(S_STRREF) if($comment=~/$regexp/);
		make_error(S_STRREF) if($name=~/$regexp/);
		make_error(S_STRREF) if($subject=~/$regexp/);
	}

	# etc etc etc

	return(0);
}

sub flood_check($$$$)
{
	my ($ip,$time,$comment,$file)=@_;
	my ($sth,$maxtime);

	if($file)
	{
		# check for to quick file posts
		$maxtime=$time-(RENZOKU2);
		$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE ip=? AND timestamp>$maxtime;") or make_error(S_SQLFAIL);
		$sth->execute($ip) or make_error(S_SQLFAIL);
		make_error(S_RENZOKU2) if(($sth->fetchrow_array())[0]);
	}
	else
	{
		# check for too quick replies or text-only posts
		$maxtime=$time-(RENZOKU);
		$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE ip=? AND timestamp>$maxtime;") or make_error(S_SQLFAIL);
		$sth->execute($ip) or make_error(S_SQLFAIL);
		make_error(S_RENZOKU) if(($sth->fetchrow_array())[0]);

		# check for repeated messages
		$maxtime=$time-(RENZOKU3);
		$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE ip=? AND comment=? AND timestamp>$maxtime;") or make_error(S_SQLFAIL);
		$sth->execute($ip,$comment) or make_error(S_SQLFAIL);
		make_error(S_RENZOKU3) if(($sth->fetchrow_array())[0]);
	}
}

sub format_comment($)
{
	my ($comment)=@_;

	# hide >>1 references from the quoting code
	$comment=~s/&gt;&gt;([0-9\-]+)/&gtgt;$1/g;

	my $handler=sub # fix up >>1 references
	{
		my $line=shift;

		$line=~s!&gtgt;([0-9]+)!
			my $res=get_post($1);
			if($res) { '<a href="'.get_reply_link($$res{num},$$res{parent}).'" onclick="highlight('.$1.')">&gt;&gt;'.$1.'</a>' }
			else { "&gt;&gt;$1"; }
		!ge;

		return $line;
	};

	if(ENABLE_WAKABAMARK) { $comment=do_wakabamark($comment,$handler) }
	else { $comment="<p>".simple_format($comment,$handler)."</p>" }

	# fix <blockquote> styles for old stylesheets
	$comment=~s/<blockquote>/<blockquote class="unkfunc">/g;

	# restore >>1 references hidden in code blocks
	$comment=~s/&gtgt;/&gt;&gt;/g;

	return $comment;
}

sub simple_format($@)
{
	my ($comment,$handler)=@_;
	return join "<br />",map
	{
		my $line=$_;

		# make URLs into links
		$line=~s{(https?://[^\s<>"]*?)((?:\s|<|>|"|\.|\)|\]|!|\?|,|&#44;|&quot;)*(?:[\s<>"]|$))}{\<a href="$1"\>$1\</a\>$2}sgi;

		# colour quoted sections if working in old-style mode.
		$line=~s!^(&gt;.*)$!\<span class="unkfunc"\>$1\</span\>!g unless(ENABLE_WAKABAMARK);

		$line=$handler->($line) if($handler);

		$line;
	} split /\n/,$comment;
}

sub encode_string($)
{
	my ($str)=@_;

	return $str unless($has_encode);
	return encode(CHARSET,$str,0x0400);
}

sub make_anonymous($$)
{
	my ($ip,$time)=@_;

	return S_ANONAME unless(SILLY_ANONYMOUS);

	my $string=$ip;
	$string.=",".int($time/86400) if(SILLY_ANONYMOUS=~/day/i);
	$string.=",".$ENV{SCRIPT_NAME} if(SILLY_ANONYMOUS=~/board/i);

	srand unpack "N",hide_data($string,4,"silly",SECRET);

	return cfg_expand("%G% %W%",
		W => ["%B%%V%%M%%I%%V%%F%","%B%%V%%M%%E%","%O%%E%","%B%%V%%M%%I%%V%%F%","%B%%V%%M%%E%","%O%%E%","%B%%V%%M%%I%%V%%F%","%B%%V%%M%%E%"],
		B => ["B","B","C","D","D","F","F","G","G","H","H","M","N","P","P","S","S","W","Ch","Br","Cr","Dr","Bl","Cl","S"],
		I => ["b","d","f","h","k","l","m","n","p","s","t","w","ch","st"],
		V => ["a","e","i","o","u"],
		M => ["ving","zzle","ndle","ddle","ller","rring","tting","nning","ssle","mmer","bber","bble","nger","nner","sh","ffing","nder","pper","mmle","lly","bling","nkin","dge","ckle","ggle","mble","ckle","rry"],
		F => ["t","ck","tch","d","g","n","t","t","ck","tch","dge","re","rk","dge","re","ne","dging"],
		O => ["Small","Snod","Bard","Billing","Black","Shake","Tilling","Good","Worthing","Blythe","Green","Duck","Pitt","Grand","Brook","Blather","Bun","Buzz","Clay","Fan","Dart","Grim","Honey","Light","Murd","Nickle","Pick","Pock","Trot","Toot","Turvey"],
		E => ["shaw","man","stone","son","ham","gold","banks","foot","worth","way","hall","dock","ford","well","bury","stock","field","lock","dale","water","hood","ridge","ville","spear","forth","will"],
		G => ["Albert","Alice","Angus","Archie","Augustus","Barnaby","Basil","Beatrice","Betsy","Caroline","Cedric","Charles","Charlotte","Clara","Cornelius","Cyril","David","Doris","Ebenezer","Edward","Edwin","Eliza","Emma","Ernest","Esther","Eugene","Fanny","Frederick","George","Graham","Hamilton","Hannah","Hedda","Henry","Hugh","Ian","Isabella","Jack","James","Jarvis","Jenny","John","Lillian","Lydia","Martha","Martin","Matilda","Molly","Nathaniel","Nell","Nicholas","Nigel","Oliver","Phineas","Phoebe","Phyllis","Polly","Priscilla","Rebecca","Reuben","Samuel","Sidney","Simon","Sophie","Thomas","Walter","Wesley","William"],
	);
}

sub make_id_code($$$)
{
	my ($ip,$time,$link)=@_;

	return EMAIL_ID if($link and DISPLAY_ID=~/link/i);
	return EMAIL_ID if($link=~/sage/i and DISPLAY_ID=~/sage/i);

	return resolve_host($ENV{REMOTE_ADDR}) if(DISPLAY_ID=~/host/i);
	return $ENV{REMOTE_ADDR} if(DISPLAY_ID=~/ip/i);

	my $string="";
	$string.=",".int($time/86400) if(DISPLAY_ID=~/day/i);
	$string.=",".$ENV{SCRIPT_NAME} if(DISPLAY_ID=~/board/i);

	return mask_ip($ENV{REMOTE_ADDR},make_key("mask",SECRET,32).$string) if(DISPLAY_ID=~/mask/i);

	return hide_data($ip.$string,6,"id",SECRET,1);
}

sub get_post($)
{
	my ($thread)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($thread) or make_error(S_SQLFAIL);

	return $sth->fetchrow_hashref();
}

sub get_parent_post($)
{
	my ($thread)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=? AND parent=0;") or make_error(S_SQLFAIL);
	$sth->execute($thread) or make_error(S_SQLFAIL);

	return $sth->fetchrow_hashref();
}

sub sage_count($)
{
	my ($parent)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE parent=? AND NOT ( timestamp<? AND ip=? );") or make_error(S_SQLFAIL);
	$sth->execute($$parent{num},$$parent{timestamp}+(NOSAGE_WINDOW),$$parent{ip}) or make_error(S_SQLFAIL);

	return ($sth->fetchrow_array())[0];
}

sub get_file_size($)
{
	my ($file)=@_;
	my (@filestats,$size);

	@filestats=stat $file;
	$size=$filestats[7];

	make_error(S_TOOBIG) if($size>MAX_KB*1024);
	make_error(S_TOOBIGORNONE) if($size==0); # check for small files, too?

	return($size);
}

sub process_file($$$)
{
	my ($file,$uploadname,$time)=@_;
	my %filetypes=FILETYPES;

	# make sure to read file in binary mode on platforms that care about such things
	binmode $file;

	# analyze file and check that it's in a supported format
	my ($ext,$width,$height)=analyze_image($file,$uploadname);

	my $known=($width or $filetypes{$ext});

	make_error(S_BADFORMAT) unless(ALLOW_UNKNOWN or $known);
	make_error(S_BADFORMAT) if(grep { $_ eq $ext } FORBIDDEN_EXTENSIONS);
	make_error(S_TOOBIG) if(MAX_IMAGE_WIDTH and $width>MAX_IMAGE_WIDTH);
	make_error(S_TOOBIG) if(MAX_IMAGE_HEIGHT and $height>MAX_IMAGE_HEIGHT);
	make_error(S_TOOBIG) if(MAX_IMAGE_PIXELS and $width*$height>MAX_IMAGE_PIXELS);

	# generate random filename - fudges the microseconds
	my $filebase=$time.sprintf("%03d",int(rand(1000)));
	my $filename=get_board_id().'/'.IMG_DIR.$filebase.'.'.$ext;
	my $thumbnail;
	if($ext eq 'png' or $ext eq 'gif') {
		$thumbnail=get_board_id().'/'.THUMB_DIR.$filebase."s.$ext";
	} else {
		$thumbnail=get_board_id().'/'.THUMB_DIR.$filebase."s.jpg";
	}

	$filename.=MUNGE_UNKNOWN unless($known);

	# do copying and MD5 checksum
	my ($md5,$md5ctx,$buffer);

	# prepare MD5 checksum if the Digest::MD5 module is available
	eval 'use Digest::MD5 qw(md5_hex)';
	$md5ctx=Digest::MD5->new unless($@);

	# copy file
	open (OUTFILE,">>$filename") or make_error(S_NOTWRITE);
	binmode OUTFILE;
	while (read($file,$buffer,1024)) # should the buffer be larger?
	{
		print OUTFILE $buffer;
		$md5ctx->add($buffer) if($md5ctx);
	}
	close $file;
	close OUTFILE;

	if($md5ctx) # if we have Digest::MD5, get the checksum
	{
		$md5=$md5ctx->hexdigest();
	}
	else # otherwise, try using the md5sum command
	{
		my $md5sum=`md5sum $filename`; # filename is always the timestamp name, and thus safe
		($md5)=$md5sum=~/^([0-9a-f]+)/ unless($?);
	}

	if($md5) # if we managed to generate an md5 checksum, check for duplicate files
	{
		my $sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE md5=?;") or make_error(S_SQLFAIL);
		$sth->execute($md5) or make_error(S_SQLFAIL);

		if(my $match=$sth->fetchrow_hashref())
		{
			unlink $filename; # make sure to remove the file
			make_error(sprintf(S_DUPE,get_reply_link($$match{num},$$match{parent})));
		}
	}

	# do thumbnail
	my ($tn_width,$tn_height,$tn_ext);

	if(!$width) # unsupported file
	{
		if($filetypes{$ext}) # externally defined filetype
		{
			open THUMBNAIL,$filetypes{$ext};
			binmode THUMBNAIL;
			($tn_ext,$tn_width,$tn_height)=analyze_image(\*THUMBNAIL,$filetypes{$ext});
			close THUMBNAIL;

			# was that icon file really there?
			if(!$tn_width) { $thumbnail=undef }
			else { $thumbnail=$filetypes{$ext} }
		}
		else
		{
			$thumbnail=undef;
		}
	}
	elsif($width>MAX_W or $height>MAX_H or THUMBNAIL_SMALL)
	{
		if($width<=MAX_W and $height<=MAX_H)
		{
			$tn_width=$width;
			$tn_height=$height;
		}
		else
		{
			$tn_width=MAX_W;
			$tn_height=int(($height*(MAX_W))/$width);

			if($tn_height>MAX_H)
			{
				$tn_width=int(($width*(MAX_H))/$height);
				$tn_height=MAX_H;
			}
		}

		if(STUPID_THUMBNAILING) { $thumbnail=$filename }
		else
		{
			$thumbnail=undef unless(make_thumbnail($filename,$thumbnail,$tn_width,$tn_height,THUMBNAIL_QUALITY,CONVERT_COMMAND));
		}
	}
	else
	{
		$tn_width=$width;
		$tn_height=$height;
		$thumbnail=$filename;
	}

	if($filetypes{$ext}) # externally defined filetype - restore the name
	{
		my $newfilename=$uploadname;
		$newfilename=~s!^.*[\\/]!!; # cut off any directory in filename
		$newfilename=get_board_id().'/'.IMG_DIR.$newfilename;

		unless(-e $newfilename) # verify no name clash
		{
			rename $filename,$newfilename;
			$thumbnail=$newfilename if($thumbnail eq $filename);
			$filename=$newfilename;
		}
		else
		{
			unlink $filename;
			make_error(S_DUPENAME);
		}
	}

        if(ENABLE_LOAD)
        {       # only called if files to be distributed across web
                $ENV{SCRIPT_NAME}=~m!^(.*/)[^/]+$!;
		my $root=$1;
                system(LOAD_SENDER_SCRIPT." $filename $root $md5 &");
        }

	my $board_path = get_board_id(); # Clear out the board path name.
    $filename  =~ s!^${board_path}/!!;
    $thumbnail =~ s!^${board_path}/!!;

	return ($filename,$md5,$width,$height,$thumbnail,$tn_width,$tn_height);
}



#
# Deleting
#

sub delete_stuff($$$$$@)
{
	my ($password,$fileonly,$archive,$admin,$ajax,@posts)=@_;
	my ($post);

	$ajax_errors=1 if $ajax;

	check_password($admin,ADMIN_PASS) if($admin);
	make_error(S_BADDELPASS) unless($password or $admin); # refuse empty password immediately

	# no password means delete always
	$password="" if($admin);

	foreach $post (@posts)
	{
		delete_post($post,$password,$fileonly,$archive);
	}

	# update the cached HTML pages
	build_cache();

	if($ajax) {
		make_json_header();
		print $JSON->encode({redir => get_board_id().'/'.HTML_SELF});
	}
	else {
		if($admin)
		{ make_http_forward(get_script_name()."?admin=$admin&task=mpanel&board=".get_board_id(), ALTERNATE_REDIRECT); }
		else
		{ make_http_forward(get_board_id().'/'.HTML_SELF,ALTERNATE_REDIRECT); }
	}
}

sub delete_post($$$$)
{
	my ($post,$password,$fileonly,$archiving)=@_;
	my ($sth,$row,$res,$reply);
	my $thumb=get_board_id().'/'.THUMB_DIR;
	my $archive=get_board_id().'/'.ARCHIVE_DIR;
	my $src=get_board_id().'/'.IMG_DIR;

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($post) or make_error(S_SQLFAIL);

	if($row=$sth->fetchrow_hashref())
	{
		make_error(S_BADDELPASS) if($password and $$row{password} ne $password);

		unless($fileonly)
		{
			# remove files from comment and possible replies
			$sth=$dbh->prepare("SELECT image,thumbnail FROM ".SQL_TABLE." WHERE num=? OR parent=?") or make_error(S_SQLFAIL);
			$sth->execute($post,$post) or make_error(S_SQLFAIL);

			while($res=$sth->fetchrow_hashref())
			{
				system(LOAD_SENDER_SCRIPT." $$res{image} &") if(ENABLE_LOAD);

				if($archiving)
				{
					# archive images
					rename $$res{image}, get_board_id().'/'.ARCHIVE_DIR.$$res{image};
					rename $$res{thumbnail}, get_board_id().'/'.ARCHIVE_DIR.$$res{thumbnail} if($$res{thumbnail}=~/^$thumb/);
				}
				else
				{
					# delete images if they exist
					unlink get_board_id().'/'.$$res{image};
					unlink get_board_id().'/'.$$res{thumbnail} if($$res{thumbnail}=~/^$thumb/);
				}
			}

			# remove post and possible replies
			$sth=$dbh->prepare("DELETE FROM ".SQL_TABLE." WHERE num=? OR parent=?;") or make_error(S_SQLFAIL);
			$sth->execute($post,$post) or make_error(S_SQLFAIL);
		}
		else # remove just the image and update the database
		{
			if($$row{image})
			{
				system(LOAD_SENDER_SCRIPT." $$row{image} &") if(ENABLE_LOAD);

				# remove images
				unlink get_board_id().'/'.$$row{image};
				unlink get_board_id().'/'.$$row{thumbnail} if($$row{thumbnail}=~/^$thumb/);

				$sth=$dbh->prepare("UPDATE ".SQL_TABLE." SET size=0,md5=null,thumbnail=null WHERE num=?;") or make_error(S_SQLFAIL);
				$sth->execute($post) or make_error(S_SQLFAIL);
			}
		}

		# fix up the thread cache
		if(!$$row{parent})
		{
			unless($fileonly) # removing an entire thread
			{
				if($archiving)
				{
					my $captcha = CAPTCHA_SCRIPT;
					my $line;

					open RESIN, '<', get_board_id().'/'.RES_DIR.$$row{num}.PAGE_EXT;
					open RESOUT, '>', get_board_id().'/'.ARCHIVE_DIR.RES_DIR.$$row{num}.PAGE_EXT;
					while($line = <RESIN>)
					{
						$line =~ s/img src="(.*?)$thumb/img src="$1$archive$thumb/g;
						if(ENABLE_LOAD)
						{
							my $redir = REDIR_DIR;
							$line =~ s/href="(.*?)$redir(.*?).html/href="$1$archive$src$2/g;
						}
						else
						{
							$line =~ s/href="(.*?)$src/href="$1$archive$src/g;
						}
						$line =~ s/src="[^"]*$captcha[^"]*"/src=""/g if(ENABLE_CAPTCHA);
						print RESOUT $line;
					}
					close RESIN;
					close RESOUT;
				}
				unlink get_board_id().'/'.RES_DIR.$$row{num}.PAGE_EXT;
				unlink get_board_id().'/'.RES_DIR.$$row{num}.".json"; # destroy json aswell?
			}
			else # removing parent image
			{
				build_thread_cache($$row{num});
			}
		}
		else # removing a reply, or a reply's image
		{
			build_thread_cache($$row{parent});
		}
	}
}



#
# Admin interface
#

sub make_admin_login()
{
	make_http_header();
	print encode_string(ADMIN_LOGIN_TEMPLATE->());
}

sub make_admin_post_panel($)
{
	my ($admin)=@_;
	my ($sth,$row,@posts,$size,$rowtype);

	check_password($admin,ADMIN_PASS);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." ORDER BY lasthit DESC,CASE parent WHEN 0 THEN num ELSE parent END ASC,num ASC;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	$size=0;
	$rowtype=1;
	while($row=get_decoded_hashref($sth))
	{
		if(!$$row{parent}) { $rowtype=1; }
		else { $rowtype^=3; }
		$$row{rowtype}=$rowtype;

		$size+=$$row{size};

		push @posts,$row;
	}

	make_http_header();
	print encode_string(POST_PANEL_TEMPLATE->(admin=>$admin,posts=>\@posts,size=>$size));
}

sub make_admin_ban_panel($)
{
	my ($admin)=@_;
	my ($sth,$row,@bans,$prevtype);

	check_password($admin,ADMIN_PASS);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_ADMIN_TABLE." WHERE type='ipban' OR type='wordban' OR type='whitelist' OR type='trust' ORDER BY type ASC,num ASC;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
	while($row=get_decoded_hashref($sth))
	{
		$$row{divider}=1 if($prevtype ne $$row{type});
		$prevtype=$$row{type};
		$$row{rowtype}=@bans%2+1;
		push @bans,$row;
	}

	make_http_header();
	print encode_string(BAN_PANEL_TEMPLATE->(admin=>$admin,bans=>\@bans));
}

sub make_admin_post($)
{
	my ($admin)=@_;

	check_password($admin,ADMIN_PASS);

	make_http_header();
	print encode_string(ADMIN_POST_TEMPLATE->(admin=>$admin));
}

sub do_login($$$$)
{
	my ($password,$nexttask,$savelogin,$admincookie)=@_;
	my $crypt;

	if($password)
	{
		$crypt=crypt_password($password);
	}
	elsif($admincookie eq crypt_password(ADMIN_PASS))
	{
		$crypt=$admincookie;
		$nexttask="mpanel";
	}

	if($crypt)
	{
		if($savelogin and $nexttask ne "nuke")
		{
			make_cookies(wakaadmin=>$crypt,
			-charset=>CHARSET,-autopath=>COOKIE_PATH,-expires=>time+365*24*3600);
		}

		make_http_forward(get_script_name()."?task=$nexttask&admin=$crypt&board=".get_board_id(), ALTERNATE_REDIRECT);
	}
	else { make_admin_login() }
}

sub do_logout()
{
	make_cookies(wakaadmin=>"",-expires=>1);
	make_http_forward(get_script_name()."?task=admin&board=".get_board_id(),ALTERNATE_REDIRECT);
}

sub do_rebuild_cache($)
{
	my ($admin)=@_;

	check_password($admin,ADMIN_PASS);

	unlink glob get_board_id().'/'.RES_DIR.'*';

	repair_database();
	build_thread_cache_all();
	build_cache();

	make_http_forward(get_board_id().'/'.HTML_SELF,ALTERNATE_REDIRECT);
}

sub add_admin_entry($$$$$$)
{
	my ($admin,$type,$comment,$ival1,$ival2,$sval1)=@_;
	my ($sth);

	check_password($admin,ADMIN_PASS);

	$comment=clean_string(decode_string($comment,CHARSET));

	$sth=$dbh->prepare("INSERT INTO ".SQL_ADMIN_TABLE." VALUES(null,?,?,?,?,?);") or make_error(S_SQLFAIL);
	$sth->execute($type,$comment,$ival1,$ival2,$sval1) or make_error(S_SQLFAIL);

	make_http_forward(get_script_name()."?admin=$admin&task=bans&board=".get_board_id(),ALTERNATE_REDIRECT);
}

sub remove_admin_entry($$)
{
	my ($admin,$num)=@_;
	my ($sth);

	check_password($admin,ADMIN_PASS);

	$sth=$dbh->prepare("DELETE FROM ".SQL_ADMIN_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($num) or make_error(S_SQLFAIL);

	make_http_forward(get_script_name()."?admin=$admin&task=bans&board=".get_board_id(),ALTERNATE_REDIRECT);
}

sub delete_all($$$)
{
	my ($admin,$ip,$mask)=@_;
	my ($sth,$row,@posts);

	check_password($admin,ADMIN_PASS);

	$sth=$dbh->prepare("SELECT num FROM ".SQL_TABLE." WHERE ip & ? = ? & ?;") or make_error(S_SQLFAIL);
	$sth->execute($mask,$ip,$mask) or make_error(S_SQLFAIL);
	while($row=$sth->fetchrow_hashref()) { push(@posts,$$row{num}); }

	delete_stuff('',0,0,$admin,0,@posts);
}

sub check_password($$)
{
	my ($admin,$password)=@_;

	return if($admin eq ADMIN_PASS);
	return if($admin eq crypt_password($password));

	make_error(S_WRONGPASS);
}

sub crypt_password($)
{
	my $crypt=hide_data((shift).$ENV{REMOTE_ADDR},9,"admin",SECRET,1);
	$crypt=~tr/+/./; # for web shit
	return $crypt;
}



#
# Page creation utils
#

sub make_http_header()
{
	print "Content-Type: ".get_xhtml_content_type(CHARSET,0)."\n";
	print "\n";
}

sub make_json_header {
    print "Cache-Control: no-cache, no-store, must-revalidate\n";
    print "Expires: Mon, 12 Apr 1997 05:00:00 GMT\n";
    print "Content-Type: application/json; charset=utf-8\n";
    print "Access-Control-Allow-Origin: *\n";
    print "\n";
}

sub make_error($)
{
	my ($error)=@_;

	if ( $ajax_errors ) {
		$error =~s/Ошибка:\s?//g;
		$error =~s/Error:\s?//g;

        make_json_header();
        print $JSON->encode({
            error => $error,
            error_code => 200
        });
    }
	else {
		make_http_header();
		print encode_string(ERROR_TEMPLATE->(error=>$error));
	}

	if($dbh)
	{
		$dbh->{Warn}=0;
		$dbh->disconnect();
	}

	if(ERRORLOG) # could print even more data, really.
	{
		open ERRORFILE,'>>'.ERRORLOG;
		print ERRORFILE $error."\n";
		print ERRORFILE $ENV{HTTP_USER_AGENT}."\n";
		print ERRORFILE "**\n";
		close ERRORFILE;
	}

	# delete temp files

	exit(0);
}

sub make_json_error {
    my $hax = shift;
    make_json_header();
    print $JSON->encode({
        error => (defined $hax ? 'Hax0r' : 'Unknown json parameter.'),
        error_code => 500
    });
    exit(0);
}

sub get_script_name()
{
	return $ENV{SCRIPT_NAME};
}

sub get_secure_script_name()
{
	return 'https://'.$ENV{SERVER_NAME}.$ENV{SCRIPT_NAME} if(USE_SECURE_ADMIN);
	return $ENV{SCRIPT_NAME};
}

sub expand_filename($)
{
	my ($filename)=@_;
	return $filename if($filename=~m!^/!);
	return $filename if($filename=~m!^\w+:!);

	my ($self_path)=$ENV{SCRIPT_NAME}=~m!^(.*/)[^/]+$!;
	return $self_path.get_board_id().'/'.$filename;
}

sub expand_image_filename($)
{
	my $filename=shift;

	return expand_filename(clean_path($filename)) unless ENABLE_LOAD;

	my ($self_path)=$ENV{SCRIPT_NAME}=~m!^(.*/)[^/]+$!;
	my $src=get_board_id().'/'.IMG_DIR;
	$filename=~/$src(.*)/;
	return $self_path.REDIR_DIR.clean_path($1).'.html';
}

sub get_reply_link($$)
{
	my ($reply,$parent)=@_;

	return expand_filename(RES_DIR.$parent.PAGE_EXT).'#'.$reply if($parent);
	return expand_filename(RES_DIR.$reply.PAGE_EXT);
}

sub get_page_count(;$)
{
	my $total=(shift or count_threads());
	return int(($total+IMAGES_PER_PAGE-1)/IMAGES_PER_PAGE);
}

sub get_filetypes()
{
	my %filetypes=FILETYPES;
	$filetypes{gif}=$filetypes{jpg}=$filetypes{png}=1;
	return join ", ",map { uc } sort keys %filetypes;
}

sub dot_to_dec($)
{
	return unpack('N',pack('C4',split(/\./, $_[0]))); # wow, magic.
}

sub dec_to_dot($)
{
	return join('.',unpack('C4',pack('N',$_[0])));
}

sub parse_range($$)
{
	my ($ip,$mask)=@_;

	$ip=dot_to_dec($ip) if($ip=~/^\d+\.\d+\.\d+\.\d+$/);

	if($mask=~/^\d+\.\d+\.\d+\.\d+$/) { $mask=dot_to_dec($mask); }
	elsif($mask=~/(\d+)/) { $mask=(~((1<<$1)-1)); }
	else { $mask=0xffffffff; }

	return ($ip,$mask);
}




#
# Database utils
#

sub init_database()
{
	my ($sth);

	$sth=$dbh->do("DROP TABLE ".SQL_TABLE.";") if(table_exists(SQL_TABLE));
	$sth=$dbh->prepare("CREATE TABLE ".SQL_TABLE." (".

	"num ".get_sql_autoincrement().",".	# Post number, auto-increments
	"parent INTEGER,".			# Parent post for replies in threads. For original posts, must be set to 0 (and not null)
	"timestamp INTEGER,".		# Timestamp in seconds for when the post was created
	"lasthit INTEGER,".			# Last activity in thread. Must be set to the same value for BOTH the original post and all replies!
	"ip TEXT,".					# IP number of poster, in integer form!

	"date TEXT,".				# The date, as a string
	"name TEXT,".				# Name of the poster
	"trip TEXT,".				# Tripcode (encoded)
	"email TEXT,".				# Email address
	"subject TEXT,".			# Subject
	"password TEXT,".			# Deletion password (in plaintext)
	"comment TEXT,".			# Comment text, HTML encoded.

	"image TEXT,".				# Image filename with path and extension (IE, src/1081231233721.jpg)
	"size INTEGER,".			# File size in bytes
	"md5 TEXT,".				# md5 sum in hex
	"width INTEGER,".			# Width of image in pixels
	"height INTEGER,".			# Height of image in pixels
	"thumbnail TEXT,".			# Thumbnail filename with path and extension
	"tn_width TEXT,".			# Thumbnail width in pixels
	"tn_height TEXT".			# Thumbnail height in pixels

	");") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
}

sub init_admin_database()
{
	my ($sth);

	$sth=$dbh->do("DROP TABLE ".SQL_ADMIN_TABLE.";") if(table_exists(SQL_ADMIN_TABLE));
	$sth=$dbh->prepare("CREATE TABLE ".SQL_ADMIN_TABLE." (".

	"num ".get_sql_autoincrement().",".	# Entry number, auto-increments
	"type TEXT,".				# Type of entry (ipban, wordban, etc)
	"comment TEXT,".			# Comment for the entry
	"ival1 TEXT,".			# Integer value 1 (usually IP)
	"ival2 TEXT,".			# Integer value 2 (usually netmask)
	"sval1 TEXT".				# String value 1

	");") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
}

sub init_proxy_database()
{
	my ($sth);

	$sth=$dbh->do("DROP TABLE ".SQL_PROXY_TABLE.";") if(table_exists(SQL_PROXY_TABLE));
	$sth=$dbh->prepare("CREATE TABLE ".SQL_PROXY_TABLE." (".

	"num ".get_sql_autoincrement().",".	# Entry number, auto-increments
	"type TEXT,".				# Type of entry (black, white, etc)
	"ip TEXT,".				# IP address
	"timestamp INTEGER,".			# Age since epoch
	"date TEXT".				# Human-readable form of date

	");") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
}

sub repair_database()
{
	my ($sth,$row,@threads,$thread);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE parent=0;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	while($row=$sth->fetchrow_hashref()) { push(@threads,$row); }

	foreach $thread (@threads)
	{
		# fix lasthit
		my ($upd);

		$upd=$dbh->prepare("UPDATE ".SQL_TABLE." SET lasthit=? WHERE parent=?;") or make_error(S_SQLFAIL);
		$upd->execute($$thread{lasthit},$$thread{num}) or make_error(S_SQLFAIL." ".$dbh->errstr());
	}
}

sub get_sql_autoincrement()
{
	return 'INTEGER PRIMARY KEY NOT NULL AUTO_INCREMENT' if(SQL_DBI_SOURCE=~/^DBI:mysql:/i);
	return 'INTEGER PRIMARY KEY' if(SQL_DBI_SOURCE=~/^DBI:SQLite:/i);
	return 'INTEGER PRIMARY KEY' if(SQL_DBI_SOURCE=~/^DBI:SQLite2:/i);

	make_error(S_SQLCONF); # maybe there should be a sane default case instead?
}

sub trim_database()
{
	my ($sth,$row,$order);

	if(TRIM_METHOD==0) { $order='num ASC'; }
	else { $order='lasthit ASC'; }

	if(MAX_AGE) # needs testing
	{
		my $mintime=time()-(MAX_AGE)*3600;

		$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE parent=0 AND timestamp<=$mintime;") or make_error(S_SQLFAIL);
		$sth->execute() or make_error(S_SQLFAIL);

		while($row=$sth->fetchrow_hashref())
		{
			delete_post($$row{num},"",0,ARCHIVE_MODE);
		}
	}

	my $threads=count_threads();
	my ($posts,$size)=count_posts();
	my $max_threads=(MAX_THREADS or $threads);
	my $max_posts=(MAX_POSTS or $posts);
	my $max_size=(MAX_MEGABYTES*1024*1024 or $size);

	while($threads>$max_threads or $posts>$max_posts or $size>$max_size)
	{
		$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE parent=0 ORDER BY $order LIMIT 1;") or make_error(S_SQLFAIL);
		$sth->execute() or make_error(S_SQLFAIL);

		if($row=$sth->fetchrow_hashref())
		{
			my ($threadposts,$threadsize)=count_posts($$row{num});

			delete_post($$row{num},"",0,ARCHIVE_MODE);

			$threads--;
			$posts-=$threadposts;
			$size-=$threadsize;
		}
		else { last; } # shouldn't happen
	}
}

sub table_exists($)
{
	my ($table)=@_;
	my ($sth);

	return 0 unless($sth=$dbh->prepare("SELECT * FROM ".$table." LIMIT 1;"));
	return 0 unless($sth->execute());
	return 1;
}

sub count_threads()
{
	my ($sth);

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE parent=0;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	return ($sth->fetchrow_array())[0];
}

sub count_posts(;$)
{
	my ($parent)=@_;
	my ($sth,$where);

	$where="WHERE parent=$parent or num=$parent" if($parent);
	$sth=$dbh->prepare("SELECT count(*),sum(size) FROM ".SQL_TABLE." $where;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	return $sth->fetchrow_array();
}

sub thread_exists($)
{
	my ($thread)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE num=? AND parent=0;") or make_error(S_SQLFAIL);
	$sth->execute($thread) or make_error(S_SQLFAIL);

	return ($sth->fetchrow_array())[0];
}

sub get_decoded_hashref($)
{
	my ($sth)=@_;

	my $row=$sth->fetchrow_hashref();

	if($row and $has_encode)
	{
		for my $k (keys %$row) # don't blame me for this shit, I got this from perlunicode.
		{ defined && /[^\000-\177]/ && Encode::_utf8_on($_) for $row->{$k}; }
	}

	return $row;
}

sub get_decoded_arrayref($)
{
	my ($sth)=@_;

	my $row=$sth->fetchrow_arrayref();

	if($row and $has_encode)
	{
		# don't blame me for this shit, I got this from perlunicode.
		defined && /[^\000-\177]/ && Encode::_utf8_on($_) for @$row;
	}

	return $row;
}
