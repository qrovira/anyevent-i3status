package AnyEvent::I3Status::Plugin::Clock;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;
use utf8;

use POSIX qw(strftime);

=head1 NAME

AnyEvent::I3Status::Plugin::Clock - Display date and time

=head1 SYNOPSIS

    Clock => {
        long_format  => "%Y-%m-%d %H:%M:%S",
        short_format => "%H:%M:%S",
        long         => 0,
    }

=head1 OPTIONS

=over

=item long_format

=item short_format

=item long

Starting long or short date format

=back

=head2 Click handlers

You can switch between long and short format clicking on the status message.

=cut

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        long_format  => "%Y-%m-%d %H:%M:%S",
        short_format => "%H:%M:%S",
        long         => 0,
        %opts
    );

    return $self;
}

sub status {
    my ($self) = @_;

    return {
        name => "clock",
        full_text => "⌚ ".strftime( $self->{long} ? $self->{long_format} : $self->{short_format}, localtime ),
        short_text => "⌚ ".strftime( $self->{short_format}, localtime ),
    };
}

sub click {
    my ($self, $click) = @_;

    $self->{long} = !$self->{long};
}

1;
