package AnyEvent::I3Status;

use 5.018;
use strict;
use warnings;

use base 'Object::Event';

use Module::Pluggable require => 1;
use AnyEvent;
use AnyEvent::Handle;
use JSON;

=head1 NAME

AnyEvent::I3Status - Generate a JSON stream for i3bar using plugins

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module bundles a simple dummy script ready to be used for i3bar
with the current set of plugins.

    $ p3status -c <config_file>

If no config file is specified, ~/.p3status will be tried, and if that
also fails, a default configuration with all available plugins with no
options will be used.

Note that the tool will try to load the configuration via C<do(...)>, which
must return a hash of options to use, including the plugin list:

    # Example file ~/.p3status
    [ 'apm', 'net', 'clock' ]


    # Another example
    {
        interval => 0.5,
        plugins  => [ qw/ apm net clock / ]
    }

See L</CONFIG> below for some more examples, and how to use ad-hoc plugins.

If you want to use this module from your own perl program:

    use AnyEvent::I3Status;

    AnyEvent::I3Status->new(
        interval => 1,
        plugins => [ qw/ net apm clock / ],

        # Planned, not yet supported, for multi-bar & click-handling
        output => \*STDOUT,
        input => \*STDIN
    );

    AnyEvent::condvar->recv;

=head1 SUBROUTINES/METHODS

=head2 new( %config )

Create a new AnyEvent::I3Status handler.

Options:

=over 4

=item interval

The interval, in seconds, on which the status heartbeat will be triggered.

=item plugins

List of plugins to enable, optionally followed by a reference to the plugin
options.

See L<AnyEvent::I3Status::Plugins> for a list of available plugins.

=item output

File descriptor to write the status output to. Unless specified, C<STDOUT> will
be used.

=item input

File descriptor to listen to for events coming from the i3wm. Unless specified,
C<STDIN> will be used.

=back

=cut



sub new {
    my ($class, %options) = @_;

    my $self = {
        interval => $options{interval} // 1,
    };

    $self->{output} = AnyEvent::Handle->new(
        fh => $options{output} // \*STDOUT
    );

    $self->{input} = AnyEvent::Handle->new(
        fh => $options{input} // \*STDIN,
        on_read => sub {
            shift->push_read( line => sub {
                my ($h, $l) = @_;
                return if $l eq '[';
                $l =~ s#^,##;
                my $j = decode_json $l;
                $self->event( click => $j );
            } );
        },
        on_error => sub {
            # Old i3wm which does not handle click events will shut stdin,
            # causing unhandled exception and stopping the loop
        }
    );

    bless $self, ref($class) || $class;

    $self->_load_plugins( $options{plugins} // [] );

    # Set up start/stop signals on USR1.. we might not want to get a TERM/CONT
    $self->{sig_stop} = AnyEvent->signal(
        signal => "USR1",
        cb     => sub { undef $self->{beat_cv}; }
    );
    $self->{sig_cont} = AnyEvent->signal(
        signal => "USR2",
        cb     => sub { $self->_setup_heartbeat; }
    );

    # Print initialization of the i3bar JSON stream
    $self->{output}->push_write(
        json => {
            version => 1,
            click_events => JSON::true,
            stop_signal => 10, # We want to stop via SIGUSR1
            cont_signal => 12  # And resume via SIGUSR2
        }
    );
    $self->{output}->push_write( "\012[\012" );

    # Finally, start things up!
    $self->_setup_heartbeat;

    return $self;
}


#
# Privates
#


# Ugly way to be able to address plugins by last module name part, also
# using lowercase.. :/
our %PLUGINS = map {
    reverse(/^(.+::([^:]+))$/),
    $_     => $_,
    lc($2) => $_,
} __PACKAGE__->plugins;

sub _load_plugins {
    my ($self, $plugins) = @_;

    my $i = 0;
    while( my $plugin = shift @$plugins ) {
        my $opts = ref($plugins->[0]) ? shift @$plugins : {};

        if( exists $PLUGINS{$plugin} ) {
            $PLUGINS{$plugin}->register( $self, prio => 100 - $i++, %$opts );
        }
        elsif( ref $opts eq 'CODE' ) {
            $self->reg_cb( heartbeat => (100 - $i++) => $opts );
        }
    }

}

# Enable the heartbeat (for init and stop/resume)
sub _setup_heartbeat {
    my $self = shift;

    return if $self->{beat_cv};

    $self->{beat_cv} = AnyEvent->timer(
        interval => $self->{interval},
        cb => sub {
            my $status = [];
            $self->event('heartbeat', $status);

            # Write status line to stdout
            $self->{output}->push_write(",") unless $self->{num_statuses}++ == 0;
            $self->{output}->push_write( json => $status );
            $self->{output}->push_write("\012");
        }
    );
}



=head1 CONFIG

The config file is loaded via C<do(...)>, which means it gets executed as a
perl script. While this is a bit stupid, it allows doing some fancy stuff, like
providing ad-hoc plugins directly on the configuration:

    # Ad-hoc plugin example:
    [
        'net',
        'disk' => { path => '/' },
        myplug => sub { push @$_[1], { full_text => time }; }
    ]

=head1 TODO

=over 4

=item Tests, tests, tests

=item Support multi-bar / multi-handler setups

=item Allow plugins to do status update bursts (e.g: cache statuses, change only 1 via own timer)

=item Turn plugins into less horrible messes

=item Plugin: add sys monitor (or extend 'load' to allow free mem, i/o load, etc.)

=item Plugin: improve net to show up/down rates

=item Plugin: add run_watch, similar to i3status one

=item Plugin: add network context checker (e.g: detect LANs like work/home/etc.)

=item Plugin: add VPN / ssh link checkers

=item Plugin: add RandR plugin, with click handling to switch modes

=back

=head1 AUTHOR

Quim Rovira, C<< <met at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-anyevent-i3status at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=AnyEvent-I3Status>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AnyEvent::I3Status


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=AnyEvent-I3Status>

=item * GitHub repository

L<http://github.com/qrovira/anyevent-i3status/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Quim Rovira.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

=cut

1; # End of AnyEvent::I3Status
