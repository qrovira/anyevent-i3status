package AnyEvent::I3Status::Plugin::Load;

use 5.018;
use strict;
use warnings;

use Sys::CpuLoad;
 
sub register {
    my ($class, $status, %opts) = @_;

    $status->reg_cb( heartbeat => $opts{prio} => sub {
        my ($self, $status) = @_;

        push @$status, {
            name => "load",
            full_text => join ' ',Sys::CpuLoad::load,
        };
    } );
}

1;
