package AnyEvent::I3Status::Plugin::Temperature;

use 5.018;
use strict;
use warnings;

use utf8;

use JSON;

 
sub register {
    my ($class, $i3status, %opts) = @_;

    $i3status->reg_cb(
        heartbeat => $opts{prio} => sub {
            my ($i3status, $status) = @_;

            my %sensors = parse_sensors();

            if( exists $opts{sensor} and $opts{sensor} eq 'all' ) {
                push @$status, sensor_status( $sensors{ $_ }, %opts )
                    foreach( keys %sensors );
            }
            elsif( exists $opts{sensor} ) {
                push @$status, sensor_status( $sensors{ $opts{sensor} }, %opts );
            }
            else {
                my ( $highest ) = sort {
                    $sensors{$b}{temp} <=>  $sensors{$a}{temp}
                } keys %sensors;

                push @$status, sensor_status( $sensors{$highest}, %opts );
            }
        }
    );
}

sub sensor_status {
    my ($sensor, %opts) = @_;

    return {
        name => "temperature",
        instance => $sensor->{name},
        full_text => $sensor->{temp}."°".$sensor->{unit}.
            ( defined($sensor->{high}) ?
                '/'.$sensor->{high}."°".$sensor->{unit} : '' ),
        ( defined($sensor->{high}) && $sensor->{temp} > $sensor->{high} ?
            (color => '#ff0000', urgent => JSON::true) : ()
        )
    };

}

sub parse_sensors {
    return map {
        /^ (?<name>[^:]+): \s+
            \+(?<temp>[\d\.]+)\302\260(?<unit>[CF]) \s+
            (?:
                \(
                    (?: high\s=\s\+(?<high>[\d\.]+)\302\260[CF], \s+)?
                    crit\s=\s\+(?<crit>[\d\.]+)\302\260[CF]
                \)
            )?
        /x ? ( $+{name} => +{ %+ } ) : ()
    } split "\n", `sensors`;
}

1;
