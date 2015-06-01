package AnyEvent::I3Status::Plugin::WebSocket;

use utf8;
use 5.014;
use strict;
use warnings;

use parent 'AnyEvent::I3Status::Plugin';

use AnyEvent;
use AnyEvent::WebSocket::Client;
use JSON;

=head1 NAME

AnyEvent::I3Status::Plugin::WebSocket - Connect to another p3status via websockets and display its statuses.

=head1 SYNOPSIS

    WebSocket => {
        host      => "127.0.0.1",
        port      => 22767,
        path      => "/",
        reconnect => 1,
    }

=head1 OPTIONS

=over

=item host

Host server where p3status service can be reached

=item port

Port on which the p3status service is listening

=item reconnect

Whether automatic reconnect should be attempted or not

=item path

Right now irrelevant

=back

=head2 Click handlers

All click events are proxied to the target server

=cut


sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        host      => '127.0.0.1',
        port      => '22767',
        path      => '/',
        status    => [],
        reconnect => 1,
        %opts
    );

    $self->connect;

    return $self;
}

sub status {
    my ($self) = @_;

    unless( $self->{client} && $self->{connection} ) {
        $self->{reconnect_countdown} ||= 5;
        if( $self->{reconnect} ) {
            if(!--$self->{reconnect_countdown} ) {
                $self->connect;
            } else {
                return { full_text => "Reconnecting in $self->{reconnect_countdown}", urgent => JSON::true };
            }
        }
        return { full_text => "Disconnected", urgent => JSON::true };
    }

    return @{ $self->{status} };
}

sub click {
    my ($self, $click) = @_;

    if( $self->{connection} ) {
        $self->{connection}->send( encode_json( $click ) );
    }
}

sub connect {
    my ($self) = @_;

    $self->{client} = AnyEvent::WebSocket::Client->new;
    $self->{client}->connect("ws://$self->{host}:$self->{port}$self->{path}")->cb( sub {
        my $connection = $self->{connection} = eval { shift->recv; };
        if( $@ ) {
            $self->{status} = [{ full_text => "Connect error: $@", urgent => JSON::true }];
            return;
        }
        $connection->on( each_message => sub {
            my ($connection, $message) = @_;
            my $body = $message->body;
            return if $body eq "[";
            $body =~ s#^,##;
            my $data = eval { decode_json($body) };
            warn "Json decode error: $@" if $@;
            $self->{status} = $data
                if ref $data eq "ARRAY";
        } );
        $connection->on( finish => sub {
            $self->{client} = $self->{connection} = undef;
        } );
    } );

}

1;
