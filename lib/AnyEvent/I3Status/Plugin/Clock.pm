package AnyEvent::I3Status::Plugin::Clock;

use 5.014;
use strict;
use warnings;
use utf8;

use POSIX qw(strftime);

sub register {
    my ($class, $i3status, %opts) = @_;

    my $long_format = $opts{long_format} // "%Y-%m-%d %H:%M:%S";
    my $short_format = $opts{short_format} // "%H:%M:%S";
    my $long = 0;

    $i3status->reg_cb(
        heartbeat => $opts{prio} => sub {
            my ($i3status, $status) = @_;

            push @$status, {
                name => "clock",
                full_text => "⌚ ".strftime( $long ? $long_format : $short_format, localtime ),
                short_text => "⌚ ".strftime( $short_format, localtime ),
            };
        },
        click => sub {
            my ($i3status, $click) = @_;

            $long = !$long
                if( $click->{name} eq 'clock' );
        }
    );

}

1;
