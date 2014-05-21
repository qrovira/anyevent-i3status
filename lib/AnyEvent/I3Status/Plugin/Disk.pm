package AnyEvent::I3Status::Plugin::Disk;

use 5.014;
use strict;
use warnings;

use Filesys::Df;

our @UNITS = ('', qw/ k M G T P /);
our %UNITS = map { $UNITS[$_] => $_ } 0..$#UNITS;

sub register {
    my ($class, $i3status, %opts) = @_;
    my $path = $opts{path};
    my $hwarn = $opts{warn} // '1G';

    return unless $path;

    $i3status->reg_cb(
        heartbeat => $opts{prio} => sub {
            my ($i3status, $status) = @_;

            my $df = df($path)
                or return;

            my $s = {
                name => "disk",
                instance => $path,
            };

            my $free = $df->{bavail} * 1024;
            my $exp = int( log($free) / log(1024) );
            my $hfree = sprintf("%.2f%s",$free/(1<<(10*$exp)),$UNITS[$exp]);
            my $warn;

            if( $hwarn =~ m#^([\d.]+)([@UNITS])$#i ) {
                $warn = $1 * (1 << (10*$UNITS{uc$2}));
            } else {
                $warn = $hwarn;
            }

            $s->{full_text} = "$path $hfree";

            if( $free < $warn ) {
                $s->{color} = '#ff0000';
                $s->{urgent} = JSON::true;
            }

            push @$status, $s;
        }
    );
}

1;
