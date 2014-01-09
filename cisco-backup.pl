#!/usr/bin/perl -w
# This is a little tool to backup Cisco routers/switches and fw over SSH.
#
# Author: tryggvi@ok.is
# License: GPLv3
#
# RHEL/Centos need to install:
# yum install -y perl-Net-SSH-Expect

use strict;
use Getopt::Long;
use Net::SSH::Expect;
no warnings;


## Settings

## Global variables
my ($o_verb, $o_help);
my ($o_host, $o_username, $o_password, $o_enable, $o_file, $o_command);

## Funtions
sub check_options {
	Getopt::Long::Configure ("bundling");
	GetOptions(
		'v'     => \$o_verb,            'verbose'	=> \$o_verb,
		'h'     => \$o_help,            'help'	=> \$o_help,
		'u:s'     => \$o_username,            'username:s'	=> \$o_username,
		'p:s'     => \$o_password,            'password:s'	=> \$o_password,
		'e:s'     => \$o_enable,            'enable-secret:s'	=> \$o_enable,
		'H:s'     => \$o_host,            'host:s'	=> \$o_host,
		'o:s'     => \$o_file,            'output-file:s'	=> \$o_file,
		'show-command:s'	=> \$o_command,
	);

	if(defined ($o_help)){
		help();
		exit 1;
	}

	if(!defined($o_host)){
		print "Host missing\n\n";
		help();
		exit 1;
	}
}

sub help() {
	print "$0\n";
        print <<EOT;
-v, --verbose
        print extra debugging information
-h, --help
	print this help message
-u, --username
	Username for authentication to host
-p, --password
	Password for authentication to host
-e, --enable-secret
	Enable secret (optional)
-H, --host
	Ipaddress for device
-o, --output-file
	Filename to write config to. If undefined write to STDOUT.
--show-command=[command]
	Override show command for backup. Default: "show running-config".
EOT
}

sub print_usage() {
        print "Usage: $0 [-v] ]\n";
}

sub printlog($){
	my ($msg) = @_;
	print $msg."\n" if $o_verb;
}

sub BackupSSH(){
	my $ssh = Net::SSH::Expect->new (
		host => $o_host,
		password=> $o_password,
		user => $o_username,
		raw_pty => 1,
		timeout => 1,
	);

	my $login_output = eval{$ssh->login();};
	printlog("Login as $o_username to $o_host");
	if ($@) {
		printlog("Login failed");
		return 0;
	}
	printlog("Login was successful");

	$login_output =~ s/\r//g; # Remove \r
	my @login_arr = split("\n", $login_output);
	my $login_count = scalar(@login_arr);
	my $login_last = $login_arr[$login_count-1];
	if ($login_last !~ />\s*/ && $login_last !~ /#\s*/){
		# Allow direct login to "enable" and to non enable
		printlog("Login failed");
		return 0;
	}

	if($o_enable){
		printlog("Enable secret defined. Trying to enable.");
		my $ls = $ssh->exec("enable");
		$ls = $ssh->exec("$o_enable");
		if($ls =~ "Password:" || $ls =~ "% Access denied"){
			printlog("Enable failed");
			return 0;
		}
	} elsif($login_output =~ ">"){
		# Re-enter user password for privilege level 15
		printlog("Enable needed. Trying to use user password to enable.");
		my $ls = $ssh->exec("enable");
		$ls = $ssh->exec("$o_password");
	}

	# Commands
	$ssh->exec("terminal pager 0");
	$ssh->exec("pager 0");
	$ssh->exec("terminal length 0");
	my $cmd = "sh running-config";
	if($o_command){
		printlog("Overwriting command with: $o_command");
		$cmd = $o_command;
	}
	printlog("Using command: $cmd");
	my $config = $ssh->exec($cmd);
	if($o_file){
		print "Writing to $o_file\n";
		open(F, ">$o_file");
		print F $config;
		close(F);
	} else {
		print "$config\n";
	}
}

## Main
check_options();

BackupSSH();
