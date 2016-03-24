#!/usr/bin/perl -w
$VERSION = "201502a";

# Simple script to push notifications and mentions to PushBullet
#
# Heavily inspired by/based on the work of:
# Derrick Staples <https://github.com/broiledmeat/pbee>
# Thorsten Leemhuis <http://www.leemhuis.info/files/fnotify/fnotify>
#
# Use:
#  /set pb_key apikey
# Where apikey is found on the Pushbullet user page
# 
# Setting a cooldown period (in seconds):
#  /set pb_cooldown 60
#
# Apply cooldown per nick
#  /set pb_pernick 1
#
# All PMs and notifications will now to forwarded to PushBullet automatically

use strict;
use vars qw($VERSION %IRSSI);

%IRSSI = (
    authors => "Jonathan Warner",
    contact => 'jaxbot@gmail.com',
    name => "pbnotifications.pl",
    description => "PushBullet notifications",
    license => "GPLv2",
    changed => "$VERSION"
);

use Data::Dumper;
use Irssi;
use Irssi::Irc;
use HTTP::Response;
use WWW::Curl::Easy;
use JSON;
use URI::Escape;

my $curl = WWW::Curl::Easy->new;
my ($pb_key, $pb_device);
my $cooldown;
my $pb_pernick;
my $away_only;
my %nick_ts;

sub initialize {
    Irssi::settings_add_str("pbnotifications", "pb_key", "");
    Irssi::settings_add_int("pbnotifications", "pb_cooldown", 0);
    Irssi::settings_add_bool("pbnotifications", "pb_pernick", 1);
    Irssi::settings_add_bool("pbnotifications", "away_only", 1);

    $pb_key = Irssi::settings_get_str("pb_key");
    $cooldown = Irssi::settings_get_int("pb_cooldown");
    $pb_pernick = Irssi::settings_get_bool("pb_pernick");
    $away_only = Irssi::settings_get_bool("away_only");

    Irssi::settings_add_str("pbnotifications", "pb_device", "");
    $pb_device = Irssi::settings_get_str("pb_device");
}

sub _push {
    if ( $away_only = 1 ) { return unless ( Irssi::active_win->{'active_server'}->{usermode_away} == 1 ) }
    my $params = shift;
    my %options = %$params;;
    my $options_str = "device_iden=$pb_device";

    foreach my $key (keys %options) {
        my $val = uri_escape($options{$key});
        $options_str .= "\&$key=$val";
    }

    $curl->setopt(CURLOPT_HEADER, 1);
    $curl->setopt(CURLOPT_URL, "https:\/\/api.pushbullet.com\/v2\/pushes");
    $curl->setopt(CURLOPT_USERPWD, "$pb_key:");
    $curl->setopt(CURLOPT_POST, 1);
    $curl->setopt(CURLOPT_POSTFIELDS, $options_str);
    $curl->setopt(CURLOPT_POSTFIELDSIZE, length($options_str));

    my $response = '';
    open(my $f, ">", \$response);
    $curl->setopt(CURLOPT_WRITEDATA, $f);
    my $retcode = $curl->perform;

    # if ($retcode != 0) {
    #     print("Issue pushing bullet");
    #     return 0;
    # }
    # return 1;
}

sub _cooldown {
    my $nick = shift;
    my $ret = 1;

    if(!$pb_pernick){
        $nick = "none";
    }
    if(exists $nick_ts{$nick}) {
        if(($nick_ts{$nick} + $cooldown) > time){
            $ret = 0;
        }
        else {
            $nick_ts{$nick} = time;
        }
    }
    else {
        $nick_ts{$nick} = time;
    }
   
    return $ret;
}

sub priv_msg {
    my ($server,$msg,$nick,$address,$target) = @_;
    my %options = ("type" => "note", "title" => "PM", "body" => $nick . ": " . $msg);
    if(_cooldown($nick)){
        if (_push(\%options)) {
            print("Pushed $nick $msg");
        }
    }
}
sub hilight {
    my ($dest, $text, $stripped) = @_;
    if ($dest->{level} & MSGLEVEL_HILIGHT) {
        my $nick = "";
        if($stripped =~ /(?:^<)(.+)(?:>)\s/) {
            $nick = $1;
        }
        my %options = ("type" => "note", "title" => "Mention", "body" => $stripped);
        if(_cooldown($nick)){
            if (_push(\%options)) {
                print("Pushed $stripped");
            }
        }
    }
}

initialize();
Irssi::signal_add("setup changed", "initialize");
Irssi::signal_add_last("message private", "priv_msg");
Irssi::signal_add_last("print text", "hilight");
Irssi::command_bind('pb_devices', 'devices');
