#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'AnyEvent::I3Status' ) || print "Bail out!\n";
}

diag( "Testing AnyEvent::I3Status $AnyEvent::I3Status::VERSION, Perl $], $^X" );
