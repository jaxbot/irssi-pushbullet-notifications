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

use Irssi;
use Irssi::Irc;
use HTTP::Response;
use WWW::Curl::Easy;
use JSON;
use URI::Query;

my $curl = WWW::Curl::Easy->new;
my ($pb_key);

sub initialize {
    Irssi::settings_add_str("pbnotifications", "pb_key", "");
    $pb_key = Irssi::settings_get_str("pb_key");
}

sub _push {
    my $params = shift;
    my $options_str = URI::Query->new(%$params)->stringify;

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

    if ($retcode != 0) {
        print("Issue pushing bullet");
        return 0;
    }
    return 1;
}

sub priv_msg {
    my ($server,$msg,$nick,$address,$target) = @_;
    my %options = ("type" => "note", "title" => "PM", "body" => $nick . ": " . $msg);
    if (_push(\%options)) {
        print("Pushed $nick $msg");
    }
}
sub hilight {
    my ($dest, $text, $stripped) = @_;
    if ($dest->{level} & MSGLEVEL_HILIGHT) {
        my %options = ("type" => "note", "title" => "Mention", "body" => $stripped);
        if (_push(\%options)) {
            print("Pushed $stripped");
        }
    }
}

initialize();
Irssi::signal_add("setup changed", "initialize");
Irssi::signal_add_last("message private", "priv_msg");
Irssi::signal_add_last("print text", "hilight");
