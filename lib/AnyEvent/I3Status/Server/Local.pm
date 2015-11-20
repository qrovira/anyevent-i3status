package AnyEvent::I3Status::Server::Local;

use 5.014;
use strict;
use warnings;

use parent 'Object::Event';

use AnyEvent;
use AnyEvent::Handle;
use JSON;

sub new {
    my ($proto, %opts) = @_;

    my $self = { %opts };

    bless( $self, ref($proto) || $proto );

    $self->{output} = AnyEvent::Handle->new(
        fh => $opts{output} // \*STDOUT
    );

    $self->{input} = AnyEvent::Handle->new(
        fh => $opts{input} // \*STDIN,
        on_read => sub {
            my ($fh) = @_;

            $fh->push_read(
                line => sub {
                    my ($h, $l) = @_;
                    return if $l eq '[' or $l eq '';
                    $l =~ s#^,##;
                    my $j = decode_json $l;
                    $self->event( click => $j );
                }
            );
        },
        on_error => sub {
            # Old i3wm which does not handle click events will shut stdin,
            # causing unhandled exception and stopping the loop
        }
    );

    # Print initialization of the i3bar JSON stream
    $self->{output}->push_write(
        json => {
            version => 1,
            click_events => JSON::true,
#            stop_signal => 10, # We want to stop via SIGUSR1
#            cont_signal => 12  # And resume via SIGUSR2
        }
    );

    $self->{output}->push_write( "\012[\012" );

    return $self;
}

sub status_update {
    my ($self, @status) = @_;

    # Optionally remove any short_statuses if needed
    # (we need to copy as refs can be reused for other server)
    if( $self->{no_short_status} ) {
        @status = map {
            my $copy = { %$_ };
            delete $copy->{short_text} if $copy->{full_text};
            $copy;
        } @status;
    }

    # Write status line to stdout
    $self->{output}->push_write(",") unless $self->{num_statuses}++ == 0;
    $self->{output}->push_write( json => \@status );
    $self->{output}->push_write("\012");
}

1;
