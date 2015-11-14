package AnyEvent::I3Status::Plugin::Graphite;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;
use utf8;

use JSON;
use List::Util qw/ sum /;
use AnyEvent::HTTP;
use AnyEvent::HTTP::Socks;

=head1 NAME

AnyEvent::I3Status::Plugin::Graphite - Display information from a graphite server

=head1 SYNOPSIS

    Graphite => {
        host => "http://my.graphite.host/",
        socks => "http://my.socks.proxy.host:port/",
    }

=head1 OPTIONS

=over

=item full

Display 1m/5m/15m averages, or only the 1m average.

=back

=head2 Click handlers

You can switch between long and short format clicking on the status message.

=cut

my %FILTERS = (
    average => sub {
        my @data = grep { defined $_->[0] } @_;
        return sum( map $_->[0], @data) / @data;
    },
);
 
sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        icon => "🔥",
        since => '-2minutes',
        refresh => 5,
        filter => "average",
        format => "%s: %.1f",
        %opts
    );

    $self->{refresh_cv} = AnyEvent->timer(
        after => 0,
        interval => $self->{refresh},
        cb => sub { $self->update_graphite() }
    );

    $self->set_status( "Wait" );

    return $self;
}

sub status {
    my ($self) = @_;

    return $self->{status};
}

sub graphite_url {
    my ($self) = shift;

    return $self->{host}.'/render/?'.join "&",
        'format=json',
        'from='.$self->{from},
        'target='.$self->{target},
        '_salt='.rand();
}

sub update_graphite {
    my ($self) = @_;

    http_request
        GET => $self->graphite_url,
        ( $self->{socks} ? ( socks => $self->{socks} ) : () ),
        sub {
            my ($json, $headers) = @_;

            if( $headers->{Status} eq "200" ) {
                my ($metric) = eval { @{ decode_json $json }; }
                    or warn "Could not deserialzie graphite JSON: ".($@ // 'Unknown error');
                
                my $value = $FILTERS{ $self->{filter} }->( @{ $metric->{datapoints} } );
                my $alarm =
                    !defined($value) ||
                    defined($self->{min}) && ($value < $self->{min}) ||
                    defined($self->{max}) && ($value < $self->{max});

                $self->set_status(
                    [ $self->{format}, ( $self->{label} // $metric->{target} ), ($value // "undef") ],
                    ( $alarm ? ( urgent => JSON::true ) : () )
                );
            } else {
                $self->set_status( "Error" );
            }
        };
}

sub set_status {
    my ($self, $text, %args) = @_;

    $self->{status} = {
        name => "graphite",
        instance => $self->{target},
        full_text => $self->_sprintf( ref($text) ? @$text : $text ),
        %args,
    };
}

sub click {
    my ($self, $click) = @_;

    $self->set_status( "Wait" );
    $self->update_graphite;

}

1;
