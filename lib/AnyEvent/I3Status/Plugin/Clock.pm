package AnyEvent::I3Status::Plugin::Clock;

use 5.018;
use strict;
use warnings;

use POSIX qw(strftime);

 
sub register {
    my ($class, $status, %opts) = @_;

    my $format = $opts{format} // "%Y-%m-%d %H:%M:%S";
    my $short_format = $opts{short_format} // "%Y-%m-%d %H:%M:%S";

    $status->reg_cb( heartbeat => $opts{prio} => sub {
        my ($self, $status) = @_;

        push @$status, {
            name => "clock",
            full_text => strftime($format, localtime),
            short_text => strftime($short_format, localtime),
        };
    } );
}

1;
