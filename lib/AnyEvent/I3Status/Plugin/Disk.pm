package AnyEvent::I3Status::Plugin::Disk;

use 5.018;
use strict;
use warnings;

use Filesys::Df;

sub register {
    my ($class, $status, %opts) = @_;
    my $path = $opts{path};
    my $warn = $opts{warn} // '95';

    return unless $path;

    $status->reg_cb( heartbeat => $opts{prio} => sub {
        my ($self, $status) = @_;

        my $df = df($path)
            or return;

        push @$status, {
            name => "disk",
            instance => $path,
            full_text => "$path $df->{per}%", 
            (
                $df->{per} > $warn ?
                ( color => '#ff0000', urgent => JSON::true ) :
                ()
            )
        };
    } );
}

1;
