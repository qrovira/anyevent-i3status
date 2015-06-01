package AnyEvent::I3Status::Server::WebSocket;

use utf8;
use 5.014;
use strict;
use warnings;

use parent 'Object::Event';

use AnyEvent;
use AnyEvent::Socket qw/tcp_server/;
use AnyEvent::WebSocket::Server;
use JSON;

sub new {
    my ($proto, %opts) = @_;

    my $self = {
        host => '127.0.0.1',
        port => '22767',
        %opts
    };

    bless( $self, ref($proto) || $proto );

    $self->{server} = AnyEvent::WebSocket::Server->new();
    $self->{tcp_server} = tcp_server $self->{host}, $self->{port}, sub {
        my ($fh, $host, $port) = @_;
        $self->{server}->establish($fh)->cb( sub {
            my $connection = eval { shift->recv };
            if( $@ ) {
                warn "Invalid connection request: $@\n";
                close $fh;
                return;
            }

            # Send i3bar handshake
            $connection->send( encode_json({
                version => 1,
                click_events => JSON::true,
                stop_signal => 10, # We want to stop via SIGUSR1
                cont_signal => 12  # And resume via SIGUSR2
            }));
            $connection->send("[");

            # Send status update when as we get them
            my $guard = $self->reg_cb(
                status_update => sub {
                    my ($self, $status) = @_;
                    $connection->send( encode_json($status) );
                }
            );

            # Receive click events from ws
            $connection->on(
                each_message => sub {
                    my ($connection, $message) = @_;
                    my $body = $message->body;
                    return if $body eq '[';
                    $body =~ s#^,##;
                    my $data = eval { decode_json($body) };
                    warn "Json decode error: $@" if $@;
                    $self->event( click => $data );
                }
            );

            # Remove status_update event handler on connection close
            $connection->on(
                finish => sub {
                    undef $connection;
                    $self->unreg_cb( $guard );
                }
            );
        } );
    };

    return $self;
}

sub status_update {
    my ($self, @status) = @_;

    $self->event( status_update => \@status );
}

1;
