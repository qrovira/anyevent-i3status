package AnyEvent::I3Status::Plugin::PidFile;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;

=head1 NAME

AnyEvent::I3Status::Plugin::PidFile - Display status of a process via it's pid file

=head1 SYNOPSIS

    Pidfile => {
        path    => "/var/run/apache2.pid",
        ok_text => "Apache OK",
    }

=head1 OPTIONS

=over

=item path

Path to the pid file

=item ok_text / err_text

Text to display when the file is found / not found. The err_text defaults to be the same as ok_text.

=item ok_color / err_color

Colors to use when the file is found / not found.

=back

=cut

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        ok_text  => $opts{path},
        ok_text  => $opts{ok_text} // $opts{path},
        %opts
    );

    return $self;
}

sub status {
    my ($self) = @_;

    if( open my $fh, '<', $self->{path} ) {
        my $pid = <$fh>;
        chomp $pid;

        if( $pid &&  $pid =~ m#^\d+$# && kill(0, $pid) ) {
            return {
                name => "pidfile",
                instance => $self->{path},
                full_text => $self->{ok_text},
                color => $self->{ok_color} // '#00ff00',
            };
        }
    }


    return {
        name => "pidfile",
        instance => $self->{path},
        full_text => $self->{err_text},
        color => $self->{err_color} // '#00ff00',
    };
}

1;
