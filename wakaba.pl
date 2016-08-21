#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;

use CGI;
use DBI;

use JSON::XS;
use Net::IP qw(:PROC); # IPv6 conversions
use Net::DNS;
use List::Util qw(first);

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

$CGI::LIST_CONTEXT_WARN = 0; # FOR DEPRECATED PERL VERSIONS
my $JSON = JSON::XS->new->pretty; #->utf8

my ($has_encode,$has_md5);

if(CONVERT_CHARSETS)
{
	eval 'use Encode qw(decode encode)';
	$has_encode=1 unless($@);
}

eval 'use Digest::MD5 qw(md5 md5_hex md5_base64)';
$has_md5=1 unless($@);

#
# Global init
#

my $protocol_re=qr/(?:http|https|ftp|mailto|nntp)/;

my ($dbh, $ajax_errors);
$dbh=DBI->connect(SQL_DBI_SOURCE,SQL_USERNAME,SQL_PASSWORD,{AutoCommit=>1}) or make_error($DBI::errstr);

return 1 if(caller); # stop here if we're being called externally

#sub init
{

	# my $query=new CGI;
	my $kotyatki = $dbh->prepare("SET NAMES 'utf8';") or make_sql_error();
	$kotyatki->execute() or make_error("SQL: Failed to set names");
	$kotyatki->finish();

	my $task=($query->param("task") or $query->param("action"));
	my $json =($query->param("json") or "");

	# create an empty file in the board directory to let migration code run
	if (-f BOARD_IDENT . "/migrate_sql") {
		# fill meta-data fields of all existing board files.
		update_db_schema();  # schema migration.
		update_files_meta();
		init_files_database() unless(table_exists(SQL_TABLE_IMG));
	}

	# check for admin table
	init_admin_database() if(!table_exists(SQL_ADMIN_TABLE));

	# check for report table
	init_report_database() if(!table_exists(SQL_REPORT_TABLE));

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
		init_files_database() unless(table_exists(SQL_TABLE_IMG));
		build_cache();
		make_http_forward(get_board_id().'/'.HTML_SELF);
	}
	elsif(!$task and !$json)
	{
		my $filename = get_board_id().'/'.HTML_SELF;
		build_cache() unless -e $filename;
		make_http_forward($filename);
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
		my $password=$query->param("password");
		my $nofile=$query->param("nofile");
		my $captcha=$query->param("captcha");
		my $admin=$query->cookie("wakaadmin");
		my $no_captcha=$query->param("no_captcha");
		my $no_format=$query->param("no_format");
		my $as_staff=$query->param("as_staff");
		my $postfix=$query->param("postfix");
		my $ajax=$query->param("ajax");
		my @files=$query->param("file");

		post_stuff(
			$parent,$spam1,$spam2,$name,$email,
			$subject,$comment,$password,
			$nofile,$captcha,$admin,$no_captcha,$no_format,
			$as_staff,$postfix,$ajax,@files
		);
	}
	elsif($task eq "delete" or $task eq decode_string(S_DELETE,CHARSET))
	{
		my $password=$query->param("password");
		my $fileonly=$query->param("fileonly");
		my $archive=$query->param("archive");
		my $admin=$query->cookie("wakaadmin");
		my $ajax=$query->param("ajax");
		my @posts=$query->param("delete");

		delete_stuff($password,$fileonly,$archive,$admin,$ajax,@posts);
	}
	elsif($task eq "report" or $task eq decode_string(S_REPORT,CHARSET))
	{
		my $sent=$query->param("sent");
		my $reason=$query->param("reason");
		my @posts=$query->param("delete");
		report_stuff($sent,$reason,@posts);
	}
    elsif ( $task eq "kontra" ) {
        my $admin    = $query->cookie("wakaadmin");
        my $threadid = $query->param("thread");
        thread_control( $admin, $threadid, "autosage" );

    }
    elsif ( $task eq "lock" ) {
        my $admin    = $query->cookie("wakaadmin");
        my $threadid = $query->param("thread");
        thread_control( $admin, $threadid, "locked" );
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
		my $admin=$query->cookie("wakaadmin");
		my $page=$query->param("page");
		make_admin_post_panel($admin,$page);
	}
	elsif($task eq "deleteall")
	{
		my $admin=$query->cookie("wakaadmin");
		my $ip=$query->param("ip");
		my $mask=$query->param("mask");
		my $go=$query->param("go");
		delete_all($admin,parse_range($ip,$mask),$go);
	}
	elsif($task eq "bans")
	{
		my $admin=$query->cookie("wakaadmin");
		make_admin_ban_panel($admin);
	}
	elsif($task eq "addip")
	{
		my $admin=$query->cookie("wakaadmin");
		my $type=$query->param("type");
		my $comment=$query->param("comment");
		my $ip=$query->param("ip");
		my $mask=$query->param("mask");
		my $expires=$query->param("expires");
		my $post=$query->param("postid");
		my $flag=$query->param("flag");
		add_admin_entry($admin,$type,$comment,parse_range($ip,$mask),'',$expires,$post,$flag);
	}
	elsif($task eq "addstring")
	{
		my $admin=$query->cookie("wakaadmin");
		my $type=$query->param("type");
		my $string=$query->param("string");
		my $comment=$query->param("comment");
		add_admin_entry($admin,$type,$comment,0,0,$string);
	}
	elsif($task eq "removeban")
	{
		my $admin=$query->cookie("wakaadmin");
		my $num=$query->param("num");
		remove_admin_entry($admin,$num);
	}
	elsif($task eq "reports")
	{
		my $admin=$query->cookie("wakaadmin");
		make_report_panel($admin);
	}
	elsif($task eq "dismiss")
	{
		my $admin=$query->cookie("wakaadmin");
		my @num=$query->param("num");
		dismiss_reports($admin,@num);
	}
	elsif ( $task eq "orphans" ) {
	    my $admin = $query->cookie("wakaadmin");
	    make_admin_orphans($admin);
	}
	elsif ( $task eq "movefiles" ) {
	    my $admin = $query->cookie("wakaadmin");
		my @files = $query->param("file"); #needs newer perl/cgi for multi_param
		move_files($admin, @files);
	}
	elsif($task eq "rebuild")
	{
		my $admin=$query->cookie("wakaadmin");
		do_rebuild_cache($admin);
	}
	elsif($task eq "showpost")
	{
		my $admin=$query->cookie("wakaadmin");
		my $thread=$query->param("thread");
        my $post=$query->param("post");
        my $after=$query->param("after");

		# outputs a single post only
        if (defined($post) and $post =~ /^[+-]?\d+$/)
        {
            show_posts($post, 0, 0, $admin);
        }
        elsif (defined($after) and $thread =~ /^[+-]?\d+$/ and $after =~ /^[+-]?\d+$/)
        {
            show_posts(0, $after, $thread, $admin);
        }
		else
		{
			make_error("Lass das sein, Kevin!");
		}
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

sub show_posts {
    my ($post, $after, $thread, $admin) = @_;
    my ($sth, $row, $single, @thread);
    my $isAdmin = 0;

    if(defined($admin))
    {
        if (check_password($admin,'','silent')) { $isAdmin = 1; }
    }

	if($after)
	{
		$single = 2;
	    $sth = $dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE parent=? and num>? ORDER BY num ASC;")
	      or make_sql_error();
	    $sth->execute( $thread, $after ) or make_sql_error();
	}
	else
	{
		$single = 1;
	    $sth = $dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=? ORDER BY num ASC;")
	      or make_sql_error();
	    $sth->execute( $post ) or make_sql_error();
	}

    if ($sth->rows) {
        make_http_header();
        while($row = get_decoded_hashref($sth))
        {
            add_images_to_row($row);
            # $$row{comment} = resolve_reflinks($$row{comment});
            push(@thread, $row);
        }
        my $output = encode_string(
			SINGLE_POST_TEMPLATE->(
                thread       => ($thread || $thread[0]{parent}),
                posts        => \@thread,
                single       => $single,
                admin        => $isAdmin,
                locked       => $thread[0]{locked}
            )
		);
        $output =~ s/^\s+//; # remove whitespace at the beginning
        $output =~ s/^\s+\n//mg; # remove empty lines
        print($output);
    }
    else {
        make_json_header();
        print encode_json( { error_code => 400 } );
    }
    $sth->finish();
}

sub build_cache()
{
	my ($sth,$row,@thread);
	my $page=0;

	# grab all posts, in thread order (ugh, ugly kludge)
	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." ORDER BY lasthit DESC,CASE parent WHEN 0 THEN num ELSE parent END ASC,num ASC") or make_sql_error();
	$sth->execute() or make_sql_error();

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
		unlink BOARD_IDENT.'/'.$page.PAGE_EXT;
		unlink BOARD_IDENT.'/'.$page.".json";
		$page++;
	}
}

sub build_cache_page($$@)
{
	my ($page,$total,@threads)=@_;
	my ($filename,$tmpname);

	if($page==0) { $filename=BOARD_IDENT.'/'.HTML_SELF; }
	else { $filename=BOARD_IDENT.'/'.$page.PAGE_EXT; }

	# do abbrevations and such
	foreach my $thread (@threads)
	{
		# append images
		add_images_to_thread(@{$$thread{posts}});
		# split off the parent post, and count the replies and images
		my ($parent,@replies)=@{$$thread{posts}};
		my $replies=@replies;
		# count files in replies - TODO: check for size == 0 for ignoring deleted files
		my $images = 0;
		foreach my $post (@replies) {
			$images += @{$$post{files}} if (exists $$post{files});
		}
		my $curr_replies=$replies;
		my $curr_images=$images;
		my $max_replies=REPLIES_PER_THREAD;
		my $max_images=(IMAGE_REPLIES_PER_THREAD or $images);

		# in case of a locked thread use custom number of replies
        if ( $$parent{locked} ) {
            $max_replies = REPLIES_PER_LOCKED_THREAD;
            $max_images = ( IMAGE_REPLIES_PER_LOCKED_THREAD or $images );
        }

		# drop replies until we have few enough replies and images
		while($curr_replies>$max_replies or $curr_images>$max_images)
		{
			my $post=shift @replies;
			# TODO: ignore files with size == 0
			$curr_images -= @{$$post{files}} if (exists $$post{files});
			$curr_replies--;
		}

		# write the shortened list of replies back
		$$thread{posts}=[$parent,@replies];
		$$thread{omit}=$replies-$curr_replies;
		$$thread{omitimages}=$images-$curr_images;
		$$thread{omitmsg}=get_omit_message($replies-$curr_replies,$images-$curr_images);

		# abbreviate the remaining posts
		foreach my $post (@{$$thread{posts}})
		{
			my $abbreviation=abbreviate_html($$post{comment},MAX_LINES_SHOWN,APPROX_LINE_LENGTH);
			if($abbreviation)
			{
                $$post{abbrev} = get_abbrev_message(count_lines($$post{comment}) - count_lines($abbreviation));
                $$post{comment_full} = $$post{comment};
                $$post{comment} = $abbreviation;
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

	if($filename eq BOARD_IDENT.'/'.HTML_SELF){
		my $output = $JSON->encode(\%json);
		print_page(BOARD_IDENT.'/'."0.json",$output);
	}
	else{
		my $output = $JSON->encode(\%json);
		print_page(BOARD_IDENT.'/'.substr($filename,0,-4)."json",$output);
	}
}

sub build_thread_cache($)
{
	my ($thread)=@_;
	my ($sth,$row,@thread);
	my ($filename,$tmpname);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=? OR parent=? ORDER BY num ASC;") or make_sql_error();
	$sth->execute($thread,$thread) or make_sql_error();

	while($row=get_decoded_hashref($sth))
	{
		hide_row_els($row);
		push(@thread,$row);
	}
	add_images_to_thread(@thread) if($thread[0]);

	make_error(S_NOTHREADERR) if($thread[0]{parent});

	$filename=BOARD_IDENT.'/'.RES_DIR.$thread.PAGE_EXT;

	my $locked = $thread[0]{locked};
	print_page($filename,PAGE_TEMPLATE->(
		thread=>$thread,
		locked=>$locked,
		postform=>((ALLOW_TEXT_REPLIES or ALLOW_IMAGE_REPLIES) and !$locked),
		image_inp=>ALLOW_IMAGE_REPLIES,
		textonly_inp=>0,
		dummy=>$thread[$#thread]{num},
		threads=>[{posts=>\@thread}])
	);

	# now build the json file
	$filename=BOARD_IDENT.'/'.RES_DIR.$thread.".json";

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

	$contents=~s/^\s+//; # remove whitespace at the beginning
	$contents=~s/^\s+\n//mg; # remove empty lines


	if(USE_TEMPFILES)
	{
		my $tmpname=BOARD_IDENT.'/'.RES_DIR.'tmp'.int(rand(1000000000));

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

	$sth=$dbh->prepare("SELECT num FROM ".SQL_TABLE." WHERE parent=0;") or make_sql_error();
	$sth->execute() or make_sql_error();

	while($row=$sth->fetchrow_arrayref())
	{
		build_thread_cache($$row[0]);
	}
}

sub get_files($$$) {
	my ($threadid, $postid, $files) = @_;
	my ($sth, $res, $where, $uploadname);

	if ($threadid)
	{
		# get all files of a thread with one query
		$where = " WHERE thread=? OR post=? ORDER BY post ASC, num ASC;";
	}
	else
	{
		# get all files of one post only
		$where = " WHERE post=? ORDER BY num ASC;";
	}

	$sth = $dbh->prepare("SELECT * FROM " . SQL_TABLE_IMG . $where) or make_sql_error();

	if ($threadid) {
		$sth->execute($threadid, $threadid) or make_sql_error();
	} else {
		$sth->execute($postid) or make_sql_error();
	}

	while ($res = get_decoded_hashref($sth)) {
		# $uploadname = remove_path($$res{uploadname});
		$$res{uploadname} = clean_string($$res{uploadname});
		$$res{displayname} = clean_string(get_displayname($$res{uploadname}));

		# static thumbs are not used anymore (for old posts)
		$$res{thumbnail} = undef if ($$res{thumbnail} =~ m|^\.\./img/|);

		# true if STUPID_THUMBNAILING is/was enabeld, do not change any paths
		unless ($$res{image} eq $$res{thumbnail}) {
			# remove any leading path that was stored in the database (for old posts)
			$$res{image} =~ s!^.*[\\/]!!;
			$$res{thumbnail} =~ s!^.*[\\/]!!;

			$$res{image} = IMG_DIR . $$res{image};  # add directory to filenames
			$$res{thumbnail} = THUMB_DIR . $$res{thumbnail} if ($$res{thumbnail});
		}

		push($files, $res);
	}
}

sub add_images_to_thread(@) {
	my (@posts) = @_;
	my ($sthfiles, $res, @files, $uploadname, $post);

	@files = ();
	get_files($posts[0]{num}, 0, \@files);
	return unless (@files);

	foreach $post (@posts) {
		while (@files and $$post{num} == $files[0]{post}) {
			push(@{$$post{files}}, shift(@files))
		}
	}
}

sub add_images_to_row($) {
    my ($row) = @_;
	my @files = (); # all files of one post for loop-processing in the template

	get_files(0, $$row{num}, \@files);
	$$row{files} = [@files] if (@files); # copy the array to an arrayref in the post
}

sub get_omit_message($$) {
	my ($posts, $files) = @_;
	return "" if !$posts;

	my $omitposts = S_ABBR1;
	$omitposts = sprintf(S_ABBR2, $posts) if ($posts > 1);

	my $omitfiles = "";
	$omitfiles = S_ABBRIMG1 if ($files == 1);
	$omitfiles = sprintf(S_ABBRIMG2, $files) if ($files > 1);

	return $omitposts . $omitfiles . S_ABBR_END;
}

sub get_abbrev_message($)
{
	my ($lines) = @_;
	return S_ABBRTEXT1 if ($lines == 1);
	return sprintf(S_ABBRTEXT2, $lines);
}

#
# JSON stuff
#

sub hide_row_els { # cut passwords and stuff from json output
    my ($row) = @_;
	$$row{'sticky'} = 0; # we don't really need stickies, right?
    delete @$row {'password', 'ip'};
}

sub output_json_post {
    my ($id) = @_;
    my ($sth, $row, $error, $code, %status, %data, %json);
    $ajax_errors = 1;

    $sth = $dbh->prepare("SELECT * FROM " . SQL_TABLE . " WHERE num=?;") or make_sql_error();
    $sth->execute($id) or make_sql_error();
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

    $sth = $dbh->prepare("SELECT * FROM " . SQL_TABLE . " WHERE parent=? and num>? ORDER BY num ASC;") or make_sql_error();
    $sth->execute($id,$after) or make_sql_error();
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
        $sth = $dbh->prepare("SELECT count(`num`) AS postcount FROM " . SQL_TABLE . " WHERE parent=? OR num=? ORDER BY num ASC;") or make_sql_error();
        $sth->execute($id, $id) or make_sql_error();

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
			max_files => MAX_FILES,
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
		$subject,$comment,$password,
		$nofile,$captcha,$admin,$no_captcha,$no_format,
		$as_staff,$postfix,$ajax,@files
	)=@_;

	my ($locked,$autosage);
	my $admin_post = 0;
	my $file = $files[0];
	# get a timestamp for future use
	my $time=time();

	$ajax_errors=1 if $ajax;

	# clean up invalid admin cookie/session or posting would fail
    my @session = check_password( $admin, '', 'silent' );
    $admin = "" unless ($session[0]);

	# check that the request came in as a POST, or from the command line
	make_error(S_UNJUST) if($ENV{REQUEST_METHOD} and $ENV{REQUEST_METHOD} ne "POST");

	if($admin) # check admin password - allow both encrypted and non-encrypted
	{
		$admin_post = 1;
	}
	else
	{
		# forbid admin-only features
		make_error(S_WRONGPASS) if($no_format or $as_staff or $postfix);

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
	make_error(S_NOPIC) if(!$parent and !$file and !$nofile and !$admin_post);

	# check for empty reply or empty text-only post
	make_error(S_NOTEXT) if($comment=~/^\s*$/ and !$file);

	# Admin capcode
	if ($as_staff) { $as_staff = 1; }
	else           { $as_staff = 0; };

	# get file size, and check for limitations.
	# my $size=get_file_size($file) if($file);
	my @size;
	for (my $i = 0; $i < MAX_FILES; $i++) {
		$size[$i] = get_file_size($files[$i]) if ($files[$i]);
	}

	# find IP
	my $ip=get_remote_addr();

	#$host = gethostbyaddr($ip);
	my $numip=dot_to_dec($ip);

	# set up cookies
	my $c_name=$name;
	my $c_email=$email;
	my $c_password=$password;

	# check if IP is whitelisted
	my $whitelisted=is_whitelisted($numip);
    dnsbl_check($ip) if (!$whitelisted and ENABLE_DNSBL_CHECK);

	# process the tripcode - maybe the string should be decoded later
	my $trip;
	($name,$trip)=process_tripcode($name,TRIPKEY,SECRET,CHARSET);

	# check for bans
	ban_check($numip,$c_name,$subject,$comment) unless $whitelisted;

	# check for spam trap fields
	if ($spam1 or $spam2) {
		my ($banip, $banmask) = parse_range($numip, '');

		my $sth = $dbh->prepare(
			"INSERT INTO " . SQL_ADMIN_TABLE . " VALUES(null,?,?,?,?,?,null);")
		  or make_sql_error();
		$sth->execute($time, 'ipban', S_AUTOBAN, $banip, $banmask)
		  or make_sql_error();

		make_error(S_SPAM);
	}

	# check captcha
	check_captcha($dbh,$captcha,$ip,$parent,BOARD_IDENT) if(ENABLE_CAPTCHA and !$admin_post and !is_trusted($trip));

	# check if thread exists, and get lasthit value
	my ($parent_res,$lasthit);
	if($parent)
	{
		$parent_res=get_parent_post($parent) or make_error(S_NOTHREADERR);
		$lasthit=$$parent_res{lasthit};
		$locked=$$parent_res{locked};
		$autosage=$$parent_res{autosage};

        make_error(S_LOCKED) if ($locked and !$admin_post);
	}
	else
	{
		$lasthit=$time;
		$locked=0;
		$autosage=0;
	}


	# kill the name if anonymous posting is being enforced
	if(FORCED_ANON)
	{
		$name='';
		$trip='';
		if($email=~/sage/i) { $email='sage'; }
		else { $email=''; }
	}

	if(!ALLOW_LINK)
	{
		if($email) { $email='sage'; }
		else { $email='' }
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
    my (@filename, @md5, @width, @height, @thumbnail, @tn_width, @tn_height, @info, @info_all, @uploadname);

	for (my $i = 0; $i < MAX_FILES; $i++) {
		if ($files[$i]) {
			# TODO: replace by $time when open_unique works
			my $file_ts = time() . sprintf("-%03d", int(rand(1000)));
			$file_ts = $time unless ($i);

			($filename[$i], $md5[$i], $width[$i], $height[$i],
				$thumbnail[$i], $tn_width[$i], $tn_height[$i],
				$info[$i], $info_all[$i], $uploadname[$i])
				= process_file($files[$i], $files[$i], $file_ts);

			# disabled because it breaks STUPID_THUMBNAILING => 1
			#$filename[$i] =~ s!.*/!!; # remove leading path before writing to database
			#$thumbnail[0] =~ s!.*/!!;
		}
	}

	# finally, write to the database
	my $sth=$dbh->prepare("INSERT INTO ".SQL_TABLE." VALUES(null,?,?,?,?,?,?,?,?,?,?,?,null,?,?,?);") or make_sql_error();
	$sth->execute($parent,$time,$lasthit,$numip,
	$date,$name,$trip,$email,$subject,$password,$comment,
	$as_staff,$autosage,$locked) or make_error($dbh->errstr);

	# find out what our new thread number is
	$sth=$dbh->prepare("SELECT num FROM ".SQL_TABLE." WHERE timestamp=? AND comment=?;") or make_sql_error();
	$sth->execute($time,$comment) or make_sql_error();
	my $num=($sth->fetchrow_array())[0];

	# insert file information into database
	if ($file) {
		$sth=$dbh->prepare("INSERT INTO " . SQL_TABLE_IMG . " VALUES(null,?,?,?,?,?,?,?,?,?,?,?,?,?);" )
			or make_sql_error();

		my $thread_id = $parent;
		$thread_id = $num if(!$parent);

		for (my $i = 0; $i < MAX_FILES; $i++) {
			($sth->execute(
				$thread_id, $num, $filename[$i], $size[$i], $md5[$i], $width[$i], $height[$i],
				$thumbnail[$i], $tn_width[$i], $tn_height[$i], $uploadname[$i], $info[$i], $info_all[$i]
			) or make_sql_error()) if ($files[$i]);
		}
	}

	if($parent and !$autosage) # bumping
	{
		my $bumplimit=(MAX_RES and sage_count($parent_res)>MAX_RES);

		# check for sage, or too many replies
		unless($email=~/sage/i or $bumplimit)
		{
			$sth=$dbh->prepare("UPDATE ".SQL_TABLE." SET lasthit=$time WHERE num=? OR parent=?;") or make_sql_error();
			$sth->execute($parent,$parent) or make_sql_error();
		}

		# bumplimit reached, set flag in thread OP
        if ($bumplimit) {
            $sth=$dbh->prepare("UPDATE ".SQL_TABLE." SET autosage=1 WHERE num=?;" ) or make_sql_error();
            $sth->execute($parent) or make_sql_error();
        }
	}

	# remove old threads from the database
	trim_database();

	# update the cached HTML pages
	build_cache();

	# update the individual thread cache
	if($parent) { build_thread_cache($parent); }
	elsif($num) { build_thread_cache($num); }

	# set the name, email and password cookies
	make_cookies(name=>$c_name,email=>$c_email,password=>$c_password,
	-charset=>CHARSET,-autopath=>COOKIE_PATH); # yum!

	if(!$ajax) {
		# redirect to the appropriate page
		if($parent) { make_http_forward(get_board_id().'/'.RES_DIR.$parent.PAGE_EXT.($num?"#$num":"")); }
		elsif($num)	{ make_http_forward(get_board_id().'/'.RES_DIR.$num.PAGE_EXT); }
		else { make_http_forward(get_board_id().'/'.HTML_SELF); } # shouldn't happen
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
	my ($sth,$where);

	if (length(pack('w', $numip)) > 5) { # IPv6 - no support for network masks yet, only single hosts
		$where = " WHERE type='whitelist' AND ival1=?;";
	} else { # IPv4
		$where = " WHERE type='whitelist' AND ? & ival2 = ival1 & ival2;";
	}

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_ADMIN_TABLE." $where;") or make_sql_error();
	$sth->execute($numip) or make_sql_error();

	return 1 if(($sth->fetchrow_array())[0]);

	return 0;
}

sub is_trusted($)
{
	my ($trip)=@_;
	my ($sth);
        $sth=$dbh->prepare("SELECT count(*) FROM ".SQL_ADMIN_TABLE." WHERE type='trust' AND sval1 = ?;") or make_sql_error();
        $sth->execute($trip) or make_sql_error();

        return 1 if(($sth->fetchrow_array())[0]);

	return 0;
}

sub clean_expired_bans()
{
	my ($sth);
	$sth=$dbh->prepare("DELETE FROM ".SQL_ADMIN_TABLE." WHERE expires AND expires<=?;") or make_sql_error();
	$sth->execute(time) or make_sql_error();
}

sub ban_check
{
    my ($numip, $name, $subject, $comment, $as_num) = @_;
    my ($sth, $row);
    my $ip=dec_to_dot($numip);

	clean_expired_bans();

	# check if the IP (ival1) belongs to a banned IP range (ival2)
	# also checks expired (sval2) and fetches the ban reason(s) (comment)
	my @bans = ();

	if ($ip =~ /:/) { # IPv6
		my $client_ip = new Net::IP($ip) or make_error(Net::IP::Error());

		# fetch all active bans from the database, regardless of actual IP version and range
		$sth =
		  $dbh->prepare( "SELECT comment,ival1,ival2,sval1,expires FROM "
			  . SQL_ADMIN_TABLE
			  . " WHERE type='ipban'"
			  . " AND LENGTH(ival1)>10"
			  . " AND (expires>? OR expires IS NULL OR expires=0)"
			  . " ORDER BY num;" )
		  or make_sql_error();
		$sth->execute(time()) or make_sql_error();

		while ($row = get_decoded_hashref($sth)) {
			# ignore IPv4 addresses
			if (length(pack('w', $$row{ival1})) > 5) {
				my $banned_ip = new Net::IP(dec_to_dot($$row{ival1})) or make_error(Net::IP::Error());
				my $mask_len = get_mask_len($$row{ival2});

				# compare binary strings of $banned_ip and $client_ip up to mask length
				my $client_bits = substr($client_ip->binip(), 0, $mask_len);
				my $banned_bits = substr($banned_ip->binip(), 0, $mask_len);
				if ($client_bits eq $banned_bits) {
					# fill $banned_bits with 0 to get a valid 128 bit IPv6 address mask
					$banned_bits .= ('0' x (128 - $mask_len));

					my ($ban);
					$$ban{ip}       = $ip;
					$$ban{network}  = ip_compress_address(ip_bintoip($banned_bits, 6), 6);
					$$ban{setbits}  = $mask_len;
					$$ban{showmask} = $$ban{setbits} < 128 ? 1 : 0;
					$$ban{reason}   = $$row{comment};
					$$ban{expires}  = $$row{expires};
					push @bans, $ban;
				}
			}
		}
	} else { # IPv4 using MySQL 5 (64 bit BIGINT) bitwise logic
		$sth =
		  $dbh->prepare( "SELECT comment,ival2,sval1,expires FROM "
			  . SQL_ADMIN_TABLE
			  . " WHERE type='ipban'"
			  . " AND LENGTH(ival1)<=10"
			  . " AND ? & ival2 = ival1 & ival2"
			  . " AND (expires>? OR expires IS NULL OR expires=0)"
			  . " ORDER BY num;" )
		  or make_sql_error();
		$sth->execute($numip, time()) or make_sql_error();

		while ($row = get_decoded_hashref($sth)) {
			my ($ban);
			$$ban{ip}       = $ip;
			$$ban{network}  = dec_to_dot($numip & $$row{ival2});
			$$ban{setbits}  = unpack("%32b*", pack('N', $$row{ival2}));
			$$ban{showmask} = $$ban{setbits} < 32 ? 1 : 0;
			$$ban{reason}   = $$row{comment};
			$$ban{expires}  = $$row{expires};
			push @bans, $ban;
		}
	}

	# this will send the ban message(s) to the client
    make_ban(S_BADHOST, @bans) if (@bans);

# fucking mysql...
#	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_ADMIN_TABLE." WHERE type='wordban' AND ? LIKE '%' || sval1 || '%';") or make_sql_error();
#	$sth->execute($comment) or make_sql_error();
#
#	make_error(S_STRREF) if(($sth->fetchrow_array())[0]);

    $sth=$dbh->prepare( "SELECT sval1,comment FROM ".SQL_ADMIN_TABLE." WHERE type='wordban';" ) or make_sql_error();
    $sth->execute() or make_sql_error();

	while($row=$sth->fetchrow_arrayref())
	{
		my $regexp=quotemeta $$row[0];
		make_error(S_STRREF) if($comment=~/$regexp/);
		make_error(S_STRREF) if($name=~/$regexp/);
		make_error(S_STRREF) if($subject=~/$regexp/);
	}

    # etc etc etc

    return (0);
}

sub dnsbl_check {
    my ($ip) = @_;
    my @errors;

    return if ($ip =~ /:/); # IPv6

    foreach my $dnsbl_info ( @{&DNSBL_INFOS} ) {
        my $dnsbl_host   = @$dnsbl_info[0];
        my $dnsbl_answers = @$dnsbl_info[1];
        my ($result, $resolver);
        my $reverse_ip    = join( '.', reverse split /\./, $ip );
        my $dnsbl_request = join( '.', $reverse_ip,        $dnsbl_host );

        $resolver = Net::DNS::Resolver->new;
        my $bgsock = $resolver->bgsend($dnsbl_request);
        my $sel    = IO::Select->new($bgsock);

        my @ready = $sel->can_read(&DNSBL_TIMEOUT);
        if (@ready) {
            foreach my $sock (@ready) {
                if ( $sock == $bgsock ) {
                    my $packet = $resolver->bgread($bgsock);
                    if ($packet) {
                        foreach my $rr ( $packet->answer ) {
                            next unless $rr->type eq "A";
                            $result = $rr->address;
                            last;
                        }
                    }
                    undef($bgsock);
                }
                $sel->remove($sock);
                undef($sock);
            }
        }

        foreach (@{$dnsbl_answers}) {
            if ( $result eq $_ ) {
                push @errors, sprintf($ajax_errors ? "IP Found in %s blacklist" : S_DNSBL, $dnsbl_host);
            }
        }
    }
    make_ban( S_BADHOSTPROXY, { ip => $ip, showmask => 0, reason => shift(@errors), expires => 0 } ) if @errors;
}

sub flood_check($$$$)
{
	my ($ip,$time,$comment,$file)=@_;
	my ($sth,$maxtime);

	if($file)
	{
		# check for to quick file posts
		$maxtime=$time-(RENZOKU2);
		$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE ip=? AND timestamp>$maxtime;") or make_sql_error();
		$sth->execute($ip) or make_sql_error();
		make_error(S_RENZOKU2) if(($sth->fetchrow_array())[0]);
	}
	else
	{
		# check for too quick replies or text-only posts
		$maxtime=$time-(RENZOKU);
		$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE ip=? AND timestamp>$maxtime;") or make_sql_error();
		$sth->execute($ip) or make_sql_error();
		make_error(S_RENZOKU) if(($sth->fetchrow_array())[0]);

		# check for repeated messages
		$maxtime=$time-(RENZOKU3);
		$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE ip=? AND comment=? AND timestamp>$maxtime;") or make_sql_error();
		$sth->execute($ip,$comment) or make_sql_error();
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
	# $comment=~s/<blockquote>/<blockquote class="unkfunc">/g;

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

	return resolve_host(get_remote_addr()) if(DISPLAY_ID=~/host/i);
	return get_remote_addr() if(DISPLAY_ID=~/ip/i);

	my $string="";
	$string.=",".int($time/86400) if(DISPLAY_ID=~/day/i);
	$string.=",".$ENV{SCRIPT_NAME} if(DISPLAY_ID=~/board/i);

	return mask_ip(get_remote_addr(),make_key("mask",SECRET,32).$string) if(DISPLAY_ID=~/mask/i);

	return hide_data($ip.$string,6,"id",SECRET,1);
}

sub get_post($)
{
	my ($thread)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=?;") or make_sql_error();
	$sth->execute($thread) or make_sql_error();

	return $sth->fetchrow_hashref();
}

sub get_parent_post($)
{
	my ($thread)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=? AND parent=0;") or make_sql_error();
	$sth->execute($thread) or make_sql_error();

	return $sth->fetchrow_hashref();
}

sub sage_count($)
{
	my ($parent)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE parent=? AND NOT ( timestamp<? AND ip=? );") or make_sql_error();
	$sth->execute($$parent{num},$$parent{timestamp}+(NOSAGE_WINDOW),$$parent{ip}) or make_sql_error();

	return ($sth->fetchrow_array())[0];
}

sub get_file_size {
    my ($file) = @_;
	my (@filestats, $errfname, $errfsize, $max_size);
    my ($size) = 0;
    my ($ext) = $file =~ /\.([^\.]+)$/;
    my %sizehash = FILESIZES;

	@filestats = stat($file);
	$size = $filestats[7];
	$max_size = MAX_KB;
	$max_size = $sizehash{$ext} if ($sizehash{$ext});
	$errfname = clean_string(decode_string($file, CHARSET));
	# or round using: int($size / 1024 + 0.5)
	$errfsize = sprintf("%.2f", $size / 1024) . " kB &gt; " . $max_size . " kB";

    make_error(S_TOOBIG . " ($errfname: $errfsize)") if ($size > $max_size * 1024);
    make_error(S_TOOBIGORNONE . " ($errfname)") if ($size == 0);  # check for small files, too?

    return ($size);
}

sub process_file {
    my ( $file, $uploadname, $time ) = @_;
    my %filetypes = FILETYPES;

	# make sure to read file in binary mode on platforms that care about such things
    binmode $file;

    # analyze file and check that it's in a supported format
    my ( $ext, $width, $height ) = analyze_image( $file, $uploadname );

    my $known = ( $width or $filetypes{$ext} );
	my $errfname = sprintf " ( %s )", clean_string(decode_string($uploadname, CHARSET));

    make_error(S_BADFORMAT.$errfname) unless ( ALLOW_UNKNOWN or $known );
    make_error(S_BADFORMAT.$errfname) if ( grep { $_ eq $ext } FORBIDDEN_EXTENSIONS );
    make_error(S_TOOBIG.$errfname) if (MAX_IMAGE_WIDTH  and $width>MAX_IMAGE_WIDTH);
    make_error(S_TOOBIG.$errfname) if (MAX_IMAGE_HEIGHT and $height>MAX_IMAGE_HEIGHT);
    make_error(S_TOOBIG.$errfname) if (MAX_IMAGE_PIXELS and $width*$height> MAX_IMAGE_PIXELS);

	# jpeg -> jpg
	$uploadname =~ s/\.jpeg$/\.jpg/i;

	# make sure $uploadname file extension matches detected extension (for internal formats)
	my ($uploadext)=$uploadname=~/\.([^\.]+)$/;
	$uploadname.=".".$ext if(lc($uploadext) ne $ext);

    # generate random filename - fudges the microseconds
    my $filebase  = $time . sprintf("-%03d", int(rand(1000)));
    my $filename  = BOARD_IDENT . '/' . IMG_DIR . $filebase . '.' . $ext;
    my $thumbnail = BOARD_IDENT . '/' . THUMB_DIR . $filebase;
	if ( $ext eq "png" or $ext eq "svg" )
	{
		$thumbnail .= "s.png";
	}
	elsif ( $ext eq "gif" )
	{
		$thumbnail .= "s.gif";
	}
	else
	{
		$thumbnail .= "s.jpg";
	}

    $filename .= MUNGE_UNKNOWN unless ($known);

    # do copying and MD5 checksum
    my ( $md5, $md5ctx, $buffer );

    # prepare MD5 checksum if the Digest::MD5 module is available
    $md5ctx = Digest::MD5->new if $has_md5;

    # copy file
    open( OUTFILE, ">>$filename" ) or make_error(S_NOTWRITE . " ($filename)");
    binmode OUTFILE;
    while ( read( $file, $buffer, 1024 ) )    # should the buffer be larger?
    {
        print OUTFILE $buffer;
        $md5ctx->add($buffer) if ($md5ctx);
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

#	if($md5) # if we managed to generate an md5 checksum, check for duplicate files
#	{
#		my $sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE md5=?;") or make_sql_error();
#		$sth->execute($md5) or make_sql_error();
#
#		if(my $match=$sth->fetchrow_hashref())
#		{
#			unlink $filename; # make sure to remove the file
#			make_error(sprintf(S_DUPE,get_reply_link($$match{num},$$match{parent})));
#		}
#	}

	my $origname=$uploadname;
	$origname=~s!^.*[\\/]!!; # cut off any directory in filename
	$origname=~tr/\0//d; # fix for dangerous 0-day

    # do thumbnail
    my ( $tn_width, $tn_height, $tn_ext );

    if ( !$width or !$filename =~ /\.svg$/ )    # unsupported file
    {
            $thumbnail = undef;
    }
    elsif ($width > MAX_W
        or $height > MAX_H
        or THUMBNAIL_SMALL
        or $filename =~ /\.svg$/ # why not check $ext?
		or $ext eq 'pdf'
		or $ext eq 'webm'
		or $ext eq 'mp4')
    {
        if ($width<=MAX_W and $height<=MAX_H)
		{
            $tn_width=$width;
            $tn_height=$height;
        }
        else
		{
            $tn_width=MAX_W;
            $tn_height=int( ( $height * (MAX_W) ) / $width );

            if ( $tn_height > MAX_H ) {
                $tn_width=int( ( $width * (MAX_H) ) / $height );
                $tn_height=MAX_H;
            }
        }

		if ($ext eq 'pdf' or $ext eq 'svg') { # cannot determine dimensions for these files
			undef($width);
			undef($height);
			$tn_width=MAX_W;
			$tn_height=MAX_H;
		}

        if (STUPID_THUMBNAILING) {
			$thumbnail=$filename;
			undef($thumbnail) if($ext eq 'pdf' or $ext eq 'svg' or $ext eq 'webm' or $ext eq 'mp4');
		}
        else {
			if ($ext eq 'webm' or $ext eq 'mp4')
			{
				undef($thumbnail)
				  unless(make_video_thumbnail($filename,$thumbnail,$tn_width,$tn_height,MAX_W,MAX_H,VIDEO_CONVERT_COMMAND));
			}
			else
			{
				undef($thumbnail)
				  unless(make_thumbnail($filename,$thumbnail,$tn_width,$tn_height,THUMBNAIL_QUALITY,ENABLE_AFMOD,CONVERT_COMMAND));
			}

			# get the thumbnail size created by external program
			if ($thumbnail and ($ext eq 'pdf' or $ext eq 'svg'))
			{
				open THUMBNAIL,$thumbnail;
				binmode THUMBNAIL;
				($tn_ext, $tn_width, $tn_height) = analyze_image(\*THUMBNAIL, $thumbnail);
				close THUMBNAIL;
			}
        }
    }
    else
	{
        $tn_width  = $width;
        $tn_height = $height;
        $thumbnail = $filename;
    }

	my ($info, $info_all) = get_meta_markup($filename, CHARSET);

	my $board_path = BOARD_IDENT; # Clear out the board path name.
    $filename  =~ s!^${board_path}/!!;
    $thumbnail =~ s!^${board_path}/!!;

    return ($filename,$md5,$width,$height,$thumbnail,$tn_width,$tn_height,$info,$info_all,$origname);
}

#
# Lock/Bumplimit
#

sub thread_control
{
    my ( $admin, $threadid, $action ) = @_;
    my ( $sth, $row );
    check_password($admin, '');

    $sth = $dbh->prepare( "SELECT locked,autosage FROM " . SQL_TABLE . " WHERE num=?;" )
      or make_sql_error();
    $sth->execute($threadid) or make_sql_error();

    if ( $row = $sth->fetchrow_hashref() ) {
        my $check;
        if($action eq "locked") {
            $check = $$row{locked} eq 1 ? 0 : 1;
            $sth = $dbh->prepare( "UPDATE " . SQL_TABLE . " SET locked=? WHERE num=? OR parent=?;" )
              or make_sql_error();
        }
        elsif($action eq "autosage") {
            $check = $$row{autosage} eq 1 ? 0 : 1;
            $sth = $dbh->prepare( "UPDATE " . SQL_TABLE . " SET autosage=? WHERE num=? OR parent=?;" )
              or make_sql_error();
        }
        else {
            make_error("dildo dodo");
        }
        $sth->execute( $check, $threadid, $threadid ) or make_sql_error();

		build_thread_cache($threadid);
		build_cache();
    }
	$sth->finish();

    make_http_forward( $ENV{HTTP_REFERER} || get_script_name()."?task=mpanel&board=".get_board_id() );
}

#
# Deleting
#

sub delete_stuff($$$$$@)
{
	my ($password,$fileonly,$archive,$admin,$ajax,@posts)=@_;
	my ($post);

	$ajax_errors=1 if $ajax;

	check_password($admin,'') if($admin);
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
		if($admin and $ENV{HTTP_REFERER}=~/task=mpanel/)
		{ make_http_forward(get_script_name()."?task=mpanel&board=".get_board_id()); }
		else
		{ make_http_forward(get_board_id().'/'.HTML_SELF); }
	}
}

sub delete_post($$$$)
{
	my ($post,$password,$fileonly,$archiving)=@_;
	my ($sth,$row,$res,$reply);
	my $thumb=THUMB_DIR;
	my $archive=ARCHIVE_DIR;
	my $src=IMG_DIR;

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=?;") or make_sql_error();
	$sth->execute($post) or make_sql_error();

	if($row=$sth->fetchrow_hashref())
	{
		make_error(S_BADDELPASS) if($password and $$row{password} ne $password);

		unless($fileonly)
		{
			# remove files from comment and possible replies
            $sth = $dbh->prepare(
                    "SELECT image,thumbnail FROM " . SQL_TABLE_IMG . " WHERE post=? OR thread=?;" )
              or make_sql_error();
            $sth->execute( $post, $post ) or make_sql_error();

			while($res=$sth->fetchrow_hashref())
			{
				if($archiving)
				{
					# archive images
					rename BOARD_IDENT.'/'.$$res{image}, BOARD_IDENT.'/'.ARCHIVE_DIR.$$res{image};
					rename BOARD_IDENT.'/'.$$res{thumbnail}, BOARD_IDENT.'/'.ARCHIVE_DIR.$$res{thumbnail} if($$res{thumbnail}=~/^$thumb/);
				}
				else
				{
					# delete images if they exist
					unlink BOARD_IDENT.'/'.$$res{image};
					unlink BOARD_IDENT.'/'.$$res{thumbnail} if($$res{thumbnail}=~/^$thumb/);
				}
			}

			$sth = $dbh->prepare(
                "DELETE FROM " . SQL_TABLE_IMG . " WHERE post=? OR thread=?;" )
              or make_sql_error();
            $sth->execute( $post, $post ) or make_sql_error();

			# remove post and possible replies
			$sth=$dbh->prepare("DELETE FROM ".SQL_TABLE." WHERE num=? OR parent=?;") or make_sql_error();
			$sth->execute($post,$post) or make_sql_error();

			# prevent GHOST BUMPING by hanging a thread where it belongs:
			# at the time of the last non sage post
            if (PREVENT_GHOST_BUMPING)
			{
                # get parent of the deleted post
				# if a thread was deleted, nothing needs to be done
                my $parent=$$row{parent};
                if ($parent)
				{
                    # its actually a post in a thread, not a thread itself
                    # find the thread to check for autosage
                    $sth=$dbh->prepare("SELECT * FROM " . SQL_TABLE . " WHERE num=?;" ) or make_sql_error();
                    $sth->execute($parent) or make_sql_error();
                    my $threadRow=$sth->fetchrow_hashref();
                    if ($threadRow and $$threadRow{autosage} != 1)
					{
						# store the thread OP timestamp value
						# will be used if no non-sage reply is found
						my $lasthit=$$threadRow{timestamp};
                        my $sth2;
                        $sth2 =
                          $dbh->prepare( "SELECT * FROM "
                              . SQL_TABLE
                              . " WHERE parent=? ORDER BY timestamp DESC;"
                          ) or make_sql_error();
                        $sth2->execute($parent) or make_sql_error();
                        my $postRow;
                        my $foundLastNonSage = 0;
                        while (($postRow = $sth2->fetchrow_hashref()) and $foundLastNonSage == 0 )
                        {
                            $foundLastNonSage = $$postRow{timestamp} if ($$postRow{email} !~ /sage/i);
                        }
						# var now contains the timestamp we have to update lasthit to
						$lasthit=$foundLastNonSage if($foundLastNonSage);
                        my $upd =
                          $dbh->prepare( "UPDATE "
                              . SQL_TABLE
                              . " SET lasthit=? WHERE parent=? OR num=?;" )
                          or make_sql_error();
                        $upd->execute( $lasthit, $parent, $parent )
                          or make_error( S_SQLFAIL ); #. " " . $dbh->errstr()
                    }
                }
            }
		}
		else # remove just the image and update the database
		{
			$sth = $dbh->prepare(
                    "SELECT image,thumbnail FROM " . SQL_TABLE_IMG . " WHERE post=?;" )
              or make_sql_error();
            $sth->execute($post) or make_sql_error();

            while ( $res = $sth->fetchrow_hashref() ) {
				# delete images if they exist
				unlink BOARD_IDENT . '/' . IMG_DIR . $$res{image};
				unlink BOARD_IDENT . '/' . THUMB_DIR . $$res{thumbnail} if($$res{thumbnail}=~/^$thumb/);
            }

			$sth = $dbh->prepare( "UPDATE "
				  . SQL_TABLE_IMG
				  . " SET size=0,md5=null,thumbnail=null,info=null,info_all=null WHERE post=?;" )
				or make_sql_error();
			$sth->execute($post) or make_sql_error();
		}

		# fix up the thread cache
		if(!$$row{parent})
		{
			unless($fileonly) # removing an entire thread
			{
				if($archiving)
				{
					my $captcha = CAPTCHA_SCRIPT;
					my $board_path = BOARD_IDENT;
					my $line;

					rename BOARD_IDENT.'/'.RES_DIR.$$row{num}.".json", BOARD_IDENT.'/'.ARCHIVE_DIR.RES_DIR.$$row{num}.".json";

					open RESIN, '<', BOARD_IDENT.'/'.RES_DIR.$$row{num}.PAGE_EXT;
					open RESOUT, '>', BOARD_IDENT.'/'.ARCHIVE_DIR.RES_DIR.$$row{num}.PAGE_EXT;
					while($line = <RESIN>)
					{
						$line =~ s/img src="(.*?)$thumb/img src="$1$archive$thumb/g;
						$line =~ s!onclick="(.*?)$thumb!onclick="$1$archive$thumb!g;
						$line =~ s!href="(.*?)$src!href="$1$archive$src!g;
						$line =~ s!src="[^"]*$captcha[^"]*"!src=""!g if(ENABLE_CAPTCHA);
						print RESOUT $line;
					}
					close RESIN;
					close RESOUT;
				}
				unlink BOARD_IDENT.'/'.RES_DIR.$$row{num}.PAGE_EXT;
				unlink BOARD_IDENT.'/'.RES_DIR.$$row{num}.".json";
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

#'
# Reporting
#

sub dismiss_reports($@)
{
	my ($admin,@num)=@_;
	my ($sth);

	check_password($admin,'');

	foreach my $entry (@num)
	{
		$sth=$dbh->prepare("DELETE FROM ".SQL_REPORT_TABLE." WHERE num=?;") or make_sql_error();
		$sth->execute($entry) or make_sql_error();
	}

	make_http_forward(get_script_name()."?task=reports&board=".get_board_id());
}

sub report_stuff(@)
{
	my ($sent,$reason,@posts)=@_;

	make_error(S_CANNOTREPORT) if(!ENABLE_REPORTS);

	# set up variables
	my $ip=$ENV{REMOTE_ADDR};
	my $numip=dot_to_dec($ip);
	my $time=time();
	my ($sth);

	# error checks
	make_error(S_NOPOSTS) if(!@posts); # no posts
	make_error(sprintf(S_REPORTSFLOOD,REPORTS_MAX)) if(@posts>REPORTS_MAX); # too many reports

	# ban check
	my $whitelisted=is_whitelisted($numip);
	ban_check($numip,'','','') unless $whitelisted;

	# we won't bother doing proxy checks - users with open proxies should be able to report too unless they're banned

	# verify each post's existence and append a hash ref with its info to the array
	my @reports=map {
		my $post=$_;
		if(my $row=get_post($post)) { $row }
		else { make_error(sprintf S_NOTEXISTPOST,$post); }
	} @posts;

	if(!$sent)
	{
		make_http_header();
		print encode_string(POST_REPORT_TEMPLATE->(posts=>\@reports));
	}
	else
	{
		make_error(S_TOOLONG) if(length($reason)>REPORTS_REASONLENGTH);

		# add reports in database
		foreach my $report (@reports)
		{
			$sth=$dbh->prepare("INSERT INTO ".SQL_REPORT_TABLE." VALUES(0,?,?,?,?,?,?);") or make_sql_error();
			$sth->execute($time,$$report{num},$$report{parent},$reason,$ip,SQL_TABLE) or make_sql_error();
		}

		make_http_header();
		print encode_string(POST_REPORT_SUCCESSFUL->());
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

sub make_admin_post_panel($;$)
{
	my ($admin,$page)=@_;
	my ($sth,$row,@posts,$rowtype);
	$page=0 if(!$page);

	check_password($admin,'');

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." ORDER BY lasthit DESC,CASE parent WHEN 0 THEN num ELSE parent END ASC,num ASC;") or make_sql_error();
	$sth->execute() or make_sql_error();

	# $size=0;
	$rowtype=1;

	my $minthreads=$page*IMAGES_PER_PAGE;
	my $maxthreads=$minthreads+IMAGES_PER_PAGE;
	my $threadcount=0;

	my ($pc,$size) = count_posts();

	while($row=get_decoded_hashref($sth))
	{
		if(!$$row{parent}) { $threadcount++; }

		if($threadcount>$minthreads and $threadcount<=$maxthreads)
		{
			if(!$$row{parent}) { $rowtype=1; }
			else { $rowtype^=3; }
			$$row{rowtype}=$rowtype;
			add_images_to_row($row);

			push @posts,$row;
		}

		$size+=$$row{size};
	}

	# Are we on a non-existent page?
	if($page!=0 and $page>($threadcount-1)/IMAGES_PER_PAGE)
	{
		make_http_forward(get_script_name()."?task=mpanel&page=0&board=".get_board_id());
		return;
	}

	my @pages=map +{ page=>$_,current=>$_==$page,url=>escamp(get_script_name()."?task=mpanel&page=$_&board=".get_board_id()) },0..($threadcount-1)/IMAGES_PER_PAGE;

	my ($prevpage,$nextpage);
	$prevpage=$page-1 if($page!=0);
	$nextpage=$page+1 if($page<$#pages);

	make_http_header();
	print encode_string(POST_PANEL_TEMPLATE->(admin=>$admin,posts=>\@posts,size=>$size,pages=>\@pages,next=>$nextpage,prev=>$prevpage));
}


sub make_admin_ban_panel($)
{
	my ($admin)=@_;
	my ($sth,$row,@bans,$prevtype);

	check_password($admin,'');

	clean_expired_bans();

	$sth=$dbh->prepare("SELECT * FROM ".SQL_ADMIN_TABLE." WHERE type='ipban' OR type='wordban' OR type='whitelist' OR type='trust' ORDER BY type ASC,num ASC;") or make_sql_error();
	$sth->execute() or make_sql_error();
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

sub make_report_panel($)
{
	my ($admin)=@_;
	my ($sth,$row,$prevboard,@reports);

	check_password($admin,'');

	$sth=$dbh->prepare("SELECT * FROM ".SQL_REPORT_TABLE." ORDER BY board ASC,num DESC;") or make_sql_error();
	$sth->execute() or make_sql_error();
	while($row=get_decoded_hashref($sth))
	{
		$$row{divider}=1 if($prevboard ne $$row{board});
		$prevboard=$$row{board};
		$$row{rowtype}=@reports%2+1;
		push @reports, $row;
	}

	make_http_header();
	print encode_string(REPORTS_TEMPLATE->(admin=>$admin,reports=>\@reports));
}

sub make_admin_orphans {
    my ($admin) = @_;
	my ($sth, $row, @results, @dbfiles, @dbthumbs);

    check_password($admin, '');

	# gather all files/thumbs on disk
	my @files = glob BOARD_IDENT . '/' . IMG_DIR . '*';
	my @thumbs = glob BOARD_IDENT . '/' . THUMB_DIR . '*';

	# remove leading board path
	$_ =~ s!^[^/]+/!! for(@files);
	$_ =~ s!^[^/]+/!! for(@thumbs);

	# gather all files/thumbs from database
	$sth = $dbh->prepare("SELECT image, thumbnail FROM ". SQL_TABLE_IMG ." WHERE size > 0 ORDER BY num ASC;")
		or make_sql_error();
	$sth->execute() or make_sql_error();
	while ($row = get_decoded_arrayref($sth)) {
		$$row[0] =~ s!.*/!!;
		$$row[0] = IMG_DIR . $$row[0];
		push(@dbfiles, $$row[0]);

		if ($$row[1]) {
			$$row[1] =~ s!.*/!!;
			$$row[1] = THUMB_DIR . $$row[1];
			push(@dbthumbs, $$row[1])
		}
	}

	# copy all entries from the disk arrays that are not found in the database arrays to new arrays
	my %dbfiles_hash = map { $_ => 1 } @dbfiles;
	my %dbthumbs_hash = map { $_ => 1 } @dbthumbs;
	my @orph_files = grep { !$dbfiles_hash{$_} } @files;
	my @orph_thumbs = grep { !$dbthumbs_hash{$_} } @thumbs;

	my $file_count = @orph_files;
	my $thumb_count = @orph_thumbs;
	my @f_orph;
	my @t_orph;

	foreach my $file (@orph_files) {
		my @result = stat(BOARD_IDENT . '/' . $file);
		my $entry = {};
		$$entry{rowtype} = @f_orph % 2 + 1;
		$$entry{name} = $file;
		$$entry{modified} = $result[9];
		$$entry{size} = $result[7];
		push(@f_orph, $entry);
	}

	foreach my $thumb (@orph_thumbs) {
		my @result = stat(BOARD_IDENT . '/' . $thumb);
		my $entry = {};
		$$entry{name} = $thumb;
		$$entry{modified} = $result[9];
		$$entry{size} = $result[7];
		push(@t_orph, $entry);
	}

	make_http_header();
	print encode_string(ADMIN_ORPHANS_TEMPLATE->(
		admin       => 1,
		files       => \@f_orph,
		thumbs      => \@t_orph,
		file_count  => $file_count,
		thumb_count => $thumb_count
	));
}

sub move_files($$){
	my ($admin, @files) = @_;
	my ($source, $target);

	check_password($admin, '');

    foreach my $file (@files) {
		$file = clean_string($file);
		if ($file =~ m!^[a-zA-Z0-9]+/[a-zA-Z0-9-]+\.[a-zA-Z0-9]+$!) {
			$source = BOARD_IDENT . '/' . $file;
			$target = BOARD_IDENT . '/' . ORPH_DIR . $file;
			rename($source, $target)
				or make_error(S_NOTWRITE . ' (' . decode_string($target, CHARSET) . ')');
		}
	}

	make_http_forward(get_script_name() . "?task=orphans&board=" . get_board_id());
}

sub do_login($$$$)
{
	my ($password,$nexttask,$savelogin,$admincookie)=@_;
	my $crypt;

	if($password)
	{
        $crypt=crypt_password($password);
        check_password($crypt,'');
    }
    elsif((check_moder($admincookie))[0] ne 0)
	{
        $crypt=$admincookie;
        $nexttask="mpanel";
    }

	if ($crypt)
	{
        my $expires = $savelogin ? time+365*24*3600 : time+1800;

		make_cookies(wakaadmin=>$crypt,
		-charset=>CHARSET,-autopath=>COOKIE_PATH,-expires=>time+365*24*3600,-httponly=>1);

		make_http_forward(get_script_name()."?task=$nexttask&board=".get_board_id());
	}
	else { make_admin_login() }
}

sub do_logout()
{
	make_cookies(wakaadmin=>"",-expires=>1);
	make_http_forward(get_script_name()."?task=admin&board=".get_board_id());
}

sub do_rebuild_cache($)
{
	my ($admin)=@_;

	check_password($admin,'');

	unlink glob BOARD_IDENT.'/'.RES_DIR.'*';

	repair_database();
	build_thread_cache_all();
	build_cache();

	make_http_forward(BOARD_IDENT().'/'.HTML_SELF);
}

sub add_admin_entry
{
	my ($admin,$type,$comment,$ival1,$ival2,$sval1,$expires,$postid,$flag)=@_;
	my ($sth);
	my $time=time();

	check_password($admin,'');

	$comment=clean_string(decode_string($comment,CHARSET));
	$comment = "no reason" if($type eq 'ipban' and !$comment);
	$expires=make_expiration_date($expires,$time);

	$sth=$dbh->prepare("INSERT INTO ".SQL_ADMIN_TABLE." VALUES(null,?,?,?,?,?,?,?);") or make_sql_error();
	$sth->execute($time,$type,$comment,$ival1,$ival2,$sval1,$expires) or make_sql_error();

	if ($postid and $flag) {
		$sth = $dbh->prepare( "UPDATE " . SQL_TABLE . " SET banned=? WHERE num=? LIMIT 1;" )
		  or make_sql_error();
		$sth->execute($time, $postid) or make_sql_error();

		build_thread_cache_all();
		build_cache();
	}

	make_http_forward(get_script_name()."?task=bans&board=".get_board_id());
}

sub remove_admin_entry($$)
{
	my ($admin,$num)=@_;
	my ($sth);

	check_password($admin,'');

	$sth=$dbh->prepare("DELETE FROM ".SQL_ADMIN_TABLE." WHERE num=?;") or make_sql_error();
	$sth->execute($num) or make_sql_error();

	make_http_forward(get_script_name()."?task=bans&board=".get_board_id());
}

sub delete_all($$$$)
{
	my ($admin,$ip,$mask,$go)=@_;
	my ($sth,$row,@posts);

	check_password($admin,'');

	unless($go and $ip) # do not allow empty IP (as it would delete anonymized (staff) posts)
	{
		my ($pcount, $tcount);

		$sth = $dbh->prepare(
			"SELECT count(*) FROM " . SQL_TABLE . " WHERE ip & ? = ? & ?;"
		) or make_sql_error();
		$sth->execute($mask, $ip, $mask) or make_sql_error();
		$pcount = ($sth->fetchrow_array())[0];

		$sth = $dbh->prepare(
			"SELECT count(*) FROM " . SQL_TABLE . " WHERE ip & ? = ? & ? AND parent=0;"
		) or make_sql_error();
		$sth->execute($mask, $ip, $mask) or make_sql_error();
		$tcount = ($sth->fetchrow_array())[0];

		make_http_header();
		print encode_string(DELETE_PANEL_TEMPLATE->(
			admin   => 1,
			ip      => $ip,
			mask    => $mask,
			posts   => $pcount,
			threads => $tcount
		));
	}
	else
	{
		$sth =
		  $dbh->prepare( "SELECT num FROM " . SQL_TABLE . " WHERE ip & ? = ? & ?;" )
		  or make_sql_error();
		$sth->execute( $mask, $ip, $mask ) or make_sql_error();
		while ( $row = $sth->fetchrow_hashref() ) { push( @posts, $$row{num} ); }

		delete_stuff('',0,0,$admin,0,@posts);
	}
}

sub check_password($$;$)
{
    my ($admin,$password,$mode) = @_;
    my @moder=check_moder($admin,$mode);

    if($password ne "")
	{
        return ('Admin', 'admin') if ($admin eq crypt_password($password));
    }
    else
	{
        return @moder if ($moder[0] ne 0);
    }

    make_error(S_WRONGPASS) if($mode ne 'silent');
    return 0;
}

sub check_moder($;$)
{
    my ($pass, $mode) = @_;
	my $moders = get_settings('mods');
    my $nick = get_moder_nick($pass,$moders);
    my @info = ( $nick, $$moders{$nick}{class}, $$moders{$nick}{boards} );

    return 0     unless( defined($nick) );
    return @info unless( @{$info[2]} ); # No board restriction

    unless ( defined( first { $_ eq BOARD_IDENT } @{$info[2]} ) )
    {
        make_error(sprintf(S_NOBOARDACC, join( ', ', @{$info[2]} ), get_script_name())) if($mode ne 'silent');
        return 0;
    }
    return @info;
}

sub get_moder_nick($$)
{
    my ($pass,$moders) = @_;
    first { crypt_password( $$moders{$_}{password} ) eq $pass } keys $moders;
}

sub crypt_password($)
{
	my $crypt=hide_data((shift).get_remote_addr(),9,"admin",SECRET,1);
	$crypt=~tr/+/./; # for web shit
	return $crypt;
}

sub get_settings {
    my ($config) = @_;
    my ($settings, $file);

    if($config eq 'mods')
	{ $file='./lib/moders.pl'; }
    # elsif($config eq 'trips')
	# { $file='./lib/config/trips.pl'; }
	else
	{ return 0; }

    # Grab code from config file and evaluate.
    open (MODCONF, $file) or return 0; # Silently fail if we cannot open file.
    binmode MODCONF, ":utf8"; # Needed for files using non-ASCII characters.

    my $board_options_code = do { local $/; <MODCONF> };
    $settings = eval $board_options_code; # Set up hash.

    # Exception for bad config.
    close MODCONF and return 0 if ($@);
    close MODCONF;

    \%$settings;
}

sub make_expiration_date($$)
{
	my ($expires,$time)=@_;

	my ($date)=grep { $$_{label} eq $expires } @{BAN_DATES()};

	if(defined $date->{time})
	{
		if($date->{time}!=0) { $expires=$time+$date->{time}; } # Use a predefined expiration time
		else { $expires=0 } # Never expire
	}
	elsif($expires!=0) { $expires=$time+$expires } # Expire in X seconds
	else { $expires=0 } # Never expire

	return $expires;
}

#
# Page creation utils
#

sub make_http_header()
{
	print "Content-Type: text/html; charset=".CHARSET."\n";
	print "\n";
}

sub make_json_header {
    print "Cache-Control: no-cache, no-store, must-revalidate\n";
    print "Expires: Mon, 12 Apr 1997 05:00:00 GMT\n";
    print "Content-Type: application/json; charset=".CHARSET."\n";
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

sub make_ban {
    my ($title, @bans) = @_;

    if ( $ajax_errors ) {
        make_json_header();
        print $JSON->encode({
            banned => 1,
            error => $title,
            bans => \@bans,
            error_code => 200
        });
    }
    else {
        make_http_header();
        print encode_string(ERROR_TEMPLATE->(
                bans           => \@bans,
                error_page     => $title,
                error_title    => $title,
                banned         => 1,
        ));
    }

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

sub make_sql_error(;$)
{
	my $debug = shift;
	make_error($debug ? $dbh->errstr : S_SQLFAIL);
}

sub get_board_id()
{
	return urlenc(encode('UTF-8', BOARD_IDENT));
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

sub root_path_to_filename($)
{
	my ($filename) = @_;
	return $filename if($filename=~m!^/!);
	return $filename if($filename=~m!^\w+:!);

	my ($self_path)=$ENV{SCRIPT_NAME}=~m!^(.*/)[^/]+$!;
	return $self_path.$filename;
}

sub expand_image_filename($)
{
	my $filename=shift;

	return expand_filename(clean_path($filename));
}

sub get_reply_link($$;$)
{
	my ($reply,$parent,$board)=@_;

    $board=(-d $board)?"/$board/":"";

	return expand_filename($board.RES_DIR.$parent.PAGE_EXT).'#'.$reply if($parent);
	return expand_filename($board.RES_DIR.$reply.PAGE_EXT);
}

sub get_page_count(;$)
{
	my $total=(shift or count_threads());
	return int(($total+IMAGES_PER_PAGE-1)/IMAGES_PER_PAGE);
}

sub get_filetypes_hash {
    my %filetypes = FILETYPES;
    $filetypes{gif} = $filetypes{jpg} = $filetypes{jpeg} = $filetypes{png} = $filetypes{svg} = 'image';
	$filetypes{pdf} = 'doc';
	$filetypes{webm} = $filetypes{mp4} = 'video';
	return %filetypes;
}

sub get_filetypes {
	my %filetypes = get_filetypes_hash();
    return join ", ", map { uc } sort keys %filetypes;
}

sub get_filetypes_table {
	my %filetypes = get_filetypes_hash();
	my %filegroups = FILEGROUPS;
	my %filesizes = FILESIZES;
	my @groups = split(' ', GROUPORDER);
	my @rows;
	my $blocks = 0;
	my $output = '<table style="margin:0px;border-collapse:collapse;display:inline-table;">' . "\n<tr>\n\t" . '<td colspan="4">'
		. sprintf(S_ALLOWED, get_displaysize(MAX_KB*1024, DECIMAL_MARK, 0)) . "</td>\n</tr><tr>\n";
	delete $filetypes{'jpeg'}; # show only jpg

	foreach my $group (@groups) {
		my @extensions;
		foreach my $ext (keys %filetypes) {
			if ($filetypes{$ext} eq $group or $group eq 'other') {
				my $ext_desc = uc($ext);
				$ext_desc .= ' (' . get_displaysize($filesizes{$ext}*1024, DECIMAL_MARK, 0) . ')' if ($filesizes{$ext});
				push(@extensions, $ext_desc);
				delete $filetypes{$ext};
			}
		}
		if (@extensions) {
			$output .= "\t<td><strong>" . $filegroups{$group} . ":</strong>&nbsp;</td>\n\t<td>"
				. join(", ", sort(@extensions)) . "&nbsp;&nbsp;</td>\n";
			$blocks++;
			if (!($blocks % 2)) {
				push(@rows, $output);
				$output = '';
				$blocks = 0;
			}
		}
	}
	push(@rows, $output) if ($output);
	return join("</tr><tr>\n", @rows) . "</tr>\n</table>";
}

sub parse_range
{
    my ( $ip, $mask ) = @_;

    if ($ip =~ /:/ or length(pack('w', $ip))>5) # IPv6
    {
        if ($mask =~ /:/) { $mask = dot_to_dec($mask); }
        else { $mask = "340282366920938463463374607431768211455"; }
    }
    else # IPv4
    {
        if( $mask =~ /^\d+\.\d+\.\d+\.\d+$/ ) { $mask = dot_to_dec($mask); }
        elsif( $mask =~ /(\d+)/ ) { $mask = ( ~( ( 1 << $1 ) - 1 ) ); }
        else { $mask = 0xffffffff; }
    }

    $ip = dot_to_dec($ip) if ( $ip =~ /(^\d+\.\d+\.\d+\.\d+$)|:/ );

    return ( $ip, $mask );
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

	"banned INTEGER,".       # Post was made by a staff member
	"adminpost INTEGER,".       # Post was made by a staff member
	"autosage INTEGER,".        # Flag to indicate that thread is on bump limit
	"locked INTEGER,".          # Thread is locked (applied to parent post only)

	");") or make_sql_error();
	$sth->execute() or make_sql_error();
}

sub init_files_database {
    my ($sth);

    $sth=$dbh->do("DROP TABLE " . SQL_TABLE_IMG . ";") if(table_exists(SQL_TABLE_IMG));
    $sth=$dbh->prepare(
		"CREATE TABLE " . SQL_TABLE_IMG . " (" .

		"num " . get_sql_autoincrement() . "," . # Primary key
		"thread INTEGER," .    # Thread ID / parent (num in comments table) of file's post
		                       # Reduces queries needed for thread output and thread deletion
		"post INTEGER," .      # Post ID (num in comments table) where file belongs to
		"image TEXT," .        # Image filename with path and extension (IE, src/1081231233721.jpg)
		"size INTEGER," .      # File size in bytes
		"md5 TEXT," .          # md5 sum in hex
		"width INTEGER," .     # Width of image in pixels
		"height INTEGER," .    # Height of image in pixels
		"thumbnail TEXT," .    # Thumbnail filename with path and extension
		"tn_width INTEGER," .  # Thumbnail width in pixels
		"tn_height INTEGER," . # Thumbnail height in pixels
		"uploadname TEXT," .   # Original filename supplied by the user agent
		"info TEXT," .         # Short file information displayed in the post
		"info_all TEXT" .      # Full file information displayed in the tooltip

		");"
    ) or make_sql_error();
    $sth->execute() or make_sql_error();

	$sth=$dbh->prepare(
		"CREATE INDEX thread ON " . SQL_TABLE_IMG . " (thread);"
    ) or make_sql_error();
    $sth->execute() or make_sql_error();

	$sth=$dbh->prepare(
		"CREATE INDEX post ON " . SQL_TABLE_IMG . " (post);"
    ) or make_sql_error();
    $sth->execute() or make_sql_error();
}

sub init_admin_database()
{
	my ($sth);

	$sth=$dbh->do("DROP TABLE ".SQL_ADMIN_TABLE.";") if(table_exists(SQL_ADMIN_TABLE));
	$sth=$dbh->prepare("CREATE TABLE ".SQL_ADMIN_TABLE." (".

	"num ".get_sql_autoincrement().",".	# Entry number, auto-increments
	"date INTEGER,".				# Time when entry was added.
	"type TEXT,".				# Type of entry (ipban, wordban, etc)
	"comment TEXT,".			# Comment for the entry
	"ival1 TEXT,".			# Integer value 1 (usually IP)
	"ival2 TEXT,".			# Integer value 2 (usually netmask)
	"sval1 TEXT,".				# String value 1
	"expires INTEGER".				# Expiry date

	");") or make_sql_error();
	$sth->execute() or make_sql_error();
}

sub init_report_database()
{
	my ($sth);

	$sth=$dbh->do("DROP TABLE ".SQL_REPORT_TABLE.";") if(table_exists(SQL_REPORT_TABLE));
	$sth=$dbh->prepare("CREATE TABLE ".SQL_REPORT_TABLE." (".

	"num ".get_sql_autoincrement().",".	# Entry number, auto-increments
	"date INTEGER,".					# Timestamp of report
	"post INTEGER,".					# Reported post
	"parent INTEGER,".					# Parent of reported post
	"reason TEXT,".						# Report reason
	"ip TEXT,".							# IP address in human-readable form
	"board TEXT".						# SQL table of board the report was made on

	");") or make_sql_error();
	$sth->execute() or make_sql_error();
}

sub repair_database()
{
	my ($sth,$row,@threads,$thread);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE parent=0;") or make_sql_error();
	$sth->execute() or make_sql_error();

	while($row=$sth->fetchrow_hashref()) { push(@threads,$row); }

	foreach $thread (@threads)
	{
		# fix lasthit
		my ($upd);

		$upd=$dbh->prepare("UPDATE ".SQL_TABLE." SET lasthit=? WHERE parent=?;") or make_sql_error();
		$upd->execute($$thread{lasthit},$$thread{num}) or make_sql_error('yes');
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

		$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE parent=0 AND timestamp<=$mintime;") or make_sql_error();
		$sth->execute() or make_sql_error();

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
		$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE parent=0 ORDER BY $order LIMIT 1;") or make_sql_error();
		$sth->execute() or make_sql_error();

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

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE parent=0;") or make_sql_error();
	$sth->execute() or make_sql_error();

	return ($sth->fetchrow_array())[0];
}

sub count_posts(;$)
{
    my ($parent) = @_;
    my ($sth, $where, $count, $size);

    $where = " WHERE parent=$parent or num=$parent" if ($parent);
    $sth = $dbh->prepare(
        "SELECT count(*) FROM " . SQL_TABLE . "$where;" )
      or make_sql_error();
    $sth->execute() or make_sql_error();
	$count = ($sth->fetchrow_array())[0];

    $where = " WHERE thread=$parent" if ($parent);
    $sth = $dbh->prepare(
        "SELECT sum(size) FROM " . SQL_TABLE_IMG . "$where;" )
      or make_sql_error();
    $sth->execute() or make_sql_error();
	$size = ($sth->fetchrow_array())[0];

    return ($count, $size);
}

sub thread_exists($)
{
	my ($thread)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE num=? AND parent=0;") or make_sql_error();
	$sth->execute($thread) or make_sql_error();

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

#
# SQL MIGRATION shit
#

sub update_db_schema { # mysql-specific. will be removed after migration is done.
# try to select a field that only exists if migration was already done
# exit if no error occurs
	my ($sth);
	my $done = 0;

    $sth = $dbh->prepare("SELECT banned FROM " . SQL_TABLE . " LIMIT 1;");
	if ($sth->execute()) {
		$sth->finish;
		$done = 1;
	}
	return if ($done);

# copy image 0 from comment table to image table
   $sth = $dbh->prepare(
		"INSERT " . SQL_TABLE_IMG . " (thread, post, image, size, md5, width, height,
		thumbnail, tn_width, tn_height, uploadname)
		SELECT parent, num, image, size, md5, width, height, thumbnail, tn_width, tn_height, image
		FROM " . SQL_TABLE . " WHERE image IS NOT NULL;"
   ) or make_error($dbh->errstr);
   $sth->execute() or make_error($dbh->errstr);

# replace thread=0 with post-id for OP images
   $sth = $dbh->prepare(
		"UPDATE " . SQL_TABLE_IMG . " SET thread=post WHERE thread=0;"
   ) or make_error($dbh->errstr);
   $sth->execute() or make_error($dbh->errstr);

# remove unneeded columns from comments table, rename column, add banned column
   $sth = $dbh->prepare(
		"ALTER TABLE " . SQL_TABLE . " DROP image, DROP size, DROP md5, DROP width, DROP height, DROP thumbnail,
		DROP tn_width, DROP tn_height, DROP origname;"
   ) or make_error($dbh->errstr);
   $sth->execute() or make_error($dbh->errstr);

# add missing columns
   	$sth = $dbh->prepare(
		"ALTER TABLE ".SQL_TABLE." ADD COLUMN banned INTEGER AFTER comment,"
		."ADD COLUMN adminpost INTEGER AFTER banned,"
		."ADD COLUMN autosage INTEGER AFTER adminpost,"
		."ADD COLUMN locked INTEGER AFTER autosage;"
	) or make_error($dbh->errstr);
	$sth->execute() or make_error($dbh->errstr);

# bans
   	$sth = $dbh->prepare(
		"ALTER TABLE ".SQL_ADMIN_TABLE." ADD COLUMN date INTEGER AFTER num,"
   		."ADD COLUMN expires INTEGER AFTER sval1;"
	) or make_error($dbh->errstr);
	$sth->execute() or make_error($dbh->errstr);
}

sub update_files_meta {
	my ($row, $sth2, $info, $info_all);
	my ($sth);

    return unless ($sth = $dbh->prepare("SELECT 1 FROM " . SQL_TABLE_IMG . " WHERE info_all IS NOT NULL LIMIT 1;"));
	return unless ($sth->execute()); # exit if schema was not yet updated

	if (($sth->fetchrow_array())[0]) { # at least one info_all field was filled. update already done, exit.
		$sth->finish;
		return;
	}

    $sth = $dbh->prepare(
		"SELECT num, image FROM " . SQL_TABLE_IMG . " WHERE image IS NOT NULL AND size>0 AND info_all IS NULL;"
	) or make_error($dbh->errstr);
    $sth->execute() or make_error($dbh->errstr);

	$sth2 = $dbh->prepare(
		"UPDATE " . SQL_TABLE_IMG . " SET info=?, info_all=? WHERE num=?;"
	) or make_error($dbh->errstr);
    while ($row = $sth->fetchrow_hashref()) {
		$$row{image} =~ s!.*/!!;
		$$row{image} = BOARD_IDENT . '/' . IMG_DIR . $$row{image};
		if (-e $$row{image}) {
			($info, $info_all) = get_meta_markup($$row{image}, CHARSET);
		} else {
			undef($info);
			$info_all = "File not found";
		}
		$sth2->execute($info, $info_all, $$row{num}) or make_error($dbh->errstr);
	}
}
