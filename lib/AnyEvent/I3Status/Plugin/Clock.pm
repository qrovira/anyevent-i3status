package AnyEvent::I3Status::Plugin::Clock;

use 5.018;
use strict;
use warnings;

use POSIX qw(strftime);

my @wheel = qw( #ff0000 #00ff00 #0000ff );
 
sub register {
    my ($class, $i3status, %opts) = @_;

    my $format = $opts{format} // "%Y-%m-%d %H:%M:%S";
    my $short_format = $opts{short_format} // "%Y-%m-%d %H:%M:%S";
    my $idx = 3;

    $i3status->reg_cb(
        heartbeat => $opts{prio} => sub {
            my ($i3status, $status) = @_;

            push @$status, {
                name => "clock",
                full_text => strftime($format, localtime),
                short_text => strftime($short_format, localtime),
                $idx < @wheel ? ( color => $wheel[$idx] ) : (),
            };
        },
        click => sub {
            my ($i3status, $click) = @_;
            if( $click->{name} eq 'clock' ) { $idx++; $idx = 0 if $idx > @wheel; }
        }
    );

}

1;
