package AnyEvent::I3Status::Plugin::File;

use 5.014;
use strict;
use warnings;

sub register {
    my ($class, $i3status, %opts) = @_;

    my $path = $opts{path} // return;
    my $ok_text = $opts{ok_text} // $path;
    my $err_text = $opts{err_text} // $opts{ok_text};

    $i3status->reg_cb(
        heartbeat => $opts{prio} => sub {
            my ($i3status, $status) = @_;

            my $s = {
                name => "file",
                instance => $path,
                full_text => $ok_text,
                $opts{ok_color} ? ( color => $opts{ok_color} ) : ()
            };

            my ($found) = glob $path;
            my @stat = $found ? stat $found : ();

            unless( @stat ) {
                $s->{full_text} = $err_text;
                $s->{color} = $opts{err_color} // '#ff0000';
            }

            push @$status, $s
                if $s->{full_text};
        },
    );

}

1;
