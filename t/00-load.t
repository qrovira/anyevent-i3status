#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

my @MODULES = qw(
    AnyEvent::I3Status
    AnyEvent::I3Status::Plugin
    AnyEvent::I3Status::Plugin::Temperature
    AnyEvent::I3Status::Plugin::Net
    AnyEvent::I3Status::Plugin::File
    AnyEvent::I3Status::Plugin::Battery
    AnyEvent::I3Status::Plugin::XRandR
    AnyEvent::I3Status::Plugin::Load
    AnyEvent::I3Status::Plugin::ScreenLock
    AnyEvent::I3Status::Plugin::Backlight
    AnyEvent::I3Status::Plugin::WebSocket
    AnyEvent::I3Status::Plugin::PidFile
    AnyEvent::I3Status::Plugin::Graphite
    AnyEvent::I3Status::Plugin::Clock
    AnyEvent::I3Status::Plugin::Disk
    AnyEvent::I3Status::Server::Local
    AnyEvent::I3Status::Server::WebSocket
);

plan tests => scalar @MODULES;

use_ok( $_ ) foreach @MODULES;

diag( "Testing AnyEvent::I3Status $AnyEvent::I3Status::VERSION, Perl $], $^X" );
