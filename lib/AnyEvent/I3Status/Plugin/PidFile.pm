package AnyEvent::I3Status::Plugin::PidFile;

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
                name => "pidfile",
                instance => $path,
                full_text => $err_text,
                color => $opts{err_color} // '#ff0000',
            };


            if( open my $fh, '<', $path ) {

                my $pid = <$fh>;
                chomp $pid;

                if( $pid &&  $pid =~ m#^\d+$# ) {

                    if( kill 0, $pid ) {

                        $s->{full_text} = $ok_text;

                        delete $s->{color};
                        $s->{color} = $opts{ok_color}
                            if $opts{ok_color};
                    }
                }
            }


            push @$status, $s
                if length $s->{full_text};
        },
    );

}

1;
