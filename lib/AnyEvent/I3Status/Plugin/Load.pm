package AnyEvent::I3Status::Plugin::Load;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;
use utf8;

use Sys::CpuLoad;

=head1 NAME

AnyEvent::I3Status::Plugin::Load - Display the system load

=head1 SYNOPSIS

    Load => {
        full => 0,
    }

=head1 OPTIONS

=over

=item full

Display 1m/5m/15m averages, or only the 1m average.

=back

=head2 Click handlers

You can switch between long and short format clicking on the status message.

=cut

 
sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        full => 0,
        icon => "🔥",
        %opts
    );

    return $self;
}

sub status {
    my ($self) = @_;
    my @loads = Sys::CpuLoad::load;

    return {
        name => "load",
        full_text => $self->_sprintf( ($self->{full} ? join ' ', @loads : $loads[0]) ),
    };
}

sub click {
    my ($self, $click) = @_;

    $self->{full} = !$self->{full};
}

1;
