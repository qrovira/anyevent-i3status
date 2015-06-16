package AnyEvent::I3Status::Plugin::Temperature;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;
use utf8;

use JSON;

=head1 NAME

AnyEvent::I3Status::Plugin::Temperature - Display system temperatures

=head1 SYNOPSIS

    Temperature => {
        sensors => "warn"
        hide_high => 0,
    }

=head1 OPTIONS

=over

=item sensors

Which sensors to display.

Can be a comma-separated list of sensors names, "crit" to display sensors over the critical limit, or "warn" to display sensors over the warning limit.

=item hide_high

Hide the high temperature limit.

=back

=cut

 
sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        sensors   => "warn",
        hide_high => 0,
        %opts
    );

    return $self;
}

sub status {
    my ($self) = @_;
    my %sensors = _parse_sensors();

    return
        map { $self->sensor_status( $sensors{ $_ } ) }
        sort { $a cmp $b } 
        (
            $self->{sensors} eq 'all' ?
            keys %sensors :
            $self->{sensors} eq 'warn' ?
            grep { $sensors{ $_ }{temp} >= $sensors{ $_ }{high} } keys %sensors :
            $self->{sensors} eq 'crit' ?
            grep { $sensors{ $_ }{temp} >= $sensors{ $_ }{crit} } keys %sensors :
            split ',', $self->{sensors}
        );
}

sub sensor_status {
    my ($self,$sensor) = @_;

    return {
        name => "temperature",
        instance => $sensor->{name},
        full_text => $sensor->{temp}."°".$sensor->{unit}.
            ( (defined($sensor->{high}) && !$self->{hide_high}) ?
                '/'.$sensor->{high}."°".$sensor->{unit} : '' ),
        ( defined($sensor->{high}) && $sensor->{temp} > $sensor->{high} ?
            (color => '#ff0000', urgent => JSON::true) : ()
        )
    };

}

sub _parse_sensors {
    return map {
        /^ (?<name>[^:]+): \s+
            \+(?<temp>[\d\.]+)\302\260(?<unit>[CF]) \s+
            (?:
                \(
                    (?: high\s=\s\+(?<high>[\d\.]+)\302\260[CF], \s+)?
                    crit\s=\s\+(?<crit>[\d\.]+)\302\260[CF]
                \)
            )?
        /x ? ( $+{name} => +{ high => $+{crit}, %+ } ) : ()
    } split "\n", `sensors`;
}

1;
