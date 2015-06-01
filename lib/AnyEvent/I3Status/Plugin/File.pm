package AnyEvent::I3Status::Plugin::File;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;

=head1 NAME

AnyEvent::I3Status::Plugin::File - Check if a file exists

=head1 SYNOPSIS

    File => {
        path      => "~/.ssh/my-control-path",
        ok_text   => "Connected",
        err_text  => "Not connected",
        ok_color  => "#00ff00",
        err_color => "#ff0000",
    }

=head1 OPTIONS

=over

=item path

Path to the file to check

=item ok_text / err_text

Text to display when the file is found / not found. The err_text defaults to be the same as ok_text.

=item ok_color / err_color

Colors to use when the file is found / not found.

=back

=cut

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        path => undef,
        ok_color  => '#00ff00',
        err_color => '#ff0000',
        %opts
    );

    $self->{ok_text} //= $self->{path};
    $self->{err_text} //= $self->{ok_text};


    return $self;
}

sub status {
    my ($self) = @_;
    my $path = $self->{path};

    my $s = {
        name      => "file",
        instance  => $path,
        full_text => $self->{err_text},
        color     => $self->{err_color},
    };

    my ($found) = glob $path;
    my @stat = $found ? stat $found : ();

    if( @stat ) {
        $s->{full_text} = $self->{ok_text};
        $s->{color} = $self->{ok_color};
    }

    return $s->{full_text} ? $s : ();
}

1;
