#!perl 

use strict;
use warnings;
use 5.018;

use AnyEvent::I3Status;
use Getopt::Long;

GetOptions(
    'config|c=s' => \(my $CONF = "$ENV{HOME}/.i3status.pl"), 
);


my $config;

# Try loading configuration from file
$config = do $CONF // {}
    if($CONF);

# Accept an array ref as configuration
$config = { plugins => $config }
    if ref $config eq 'ARRAY';

# Select ALL plugins unless we have some
$config->{plugins} = [ AnyEvent::I3Status->plugins ]
    unless $config->{plugins};

# Create status handler
my $i3 = AnyEvent::I3Status->new(%$config);

# Loop forever
AnyEvent->condvar->recv;


