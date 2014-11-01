package AnyEvent::I3Status::Plugin::Load;

use 5.014;
use strict;
use warnings;
use utf8;

use Sys::CpuLoad;
 
sub register {
    my ($class, $i3status, %opts) = @_;

    my $full = 0;

    $i3status->reg_cb(
        heartbeat => $opts{prio} => sub {
            my ($i3status, $status) = @_;
            my @loads = Sys::CpuLoad::load;

            push @$status, {
                name => "load",
                full_text => "☸ ". ($full ? join ' ', @loads : $loads[0]),
            };
        },
        click => sub {
            my ($i3status, $click) = @_;

            $full = !$full
                if( $click->{name} eq "load" );
        }
    );
}

1;
