package AnyEvent::I3Status;

use 5.014;
use strict;
use warnings;

use parent 'Object::Event';

use AnyEvent;
use AnyEvent::Handle;
use JSON;

our $VERSION = '0.02';

=head1 NAME

AnyEvent::I3Status - Generate statuses for i3-wm's awesome i3bar

=head1 SYNOPSIS

L<AnyEvent::I3Status> is an alternative to F<i3status> built in Perl and using
L<AnyEvent>. It bundles most common plugins (eg. network and disk status, clocks,
battery, etc.), but also provides a few powerful features like the ability to
use websockets to display remote statuses from other computers.

It comes with a small script (F<p3status>) ready to be used with
minimum configuration.

    $ p3status -c <config_file>

If no config file is specified, it will try to read F<~/.p3status>, and if that
also fails, a default configuration with the default plugins will be used.

The configuration file will be evaluated as a Perl script, which should return either
an array of plugins to be used, or a hash of options.

    # Example file ~/.p3status
    [ 'Battery', 'Net', 'Clock' ]


    # A more complete example
    {
        # Refresh the status every 0.5 seconds
        interval => 0.5,
        plugins  => [
            'Net',
            'Disk' => { path => '/', warn => '2G', hide_ok => 1 },
            'Disk' => { path => '/home', warn => '2G', hide_ok => 1 },
            'Load',
            'Backlight' => { device => "intel_backlight" },
            'Battery',
            'Clock',
            'ScreenLock',
        ]
    }


    # A dummy client that just pulls status via WebSocket plugin
    [ WebSocket => { host => "10.0.0.100", port => 33333 } ]


    # A server providing the statuses via WebSocket
    {
        servers => [
            WebSocket => { host => "127.0.0.1", port => 33333 },
        ],
        plugins  => [
            'Net',
            'Load',
        ]
    }

The top-level options on the configuration are the same as the options accepted
by C<new> below.

=head1 METHODS

L<AnyEvent::I3Status> inherits all methods from L<Object::Event> and implements the following ones:

=head2 new( %config )

Create a new AnyEvent::I3Status handler.

B<Options:>

=over

=item interval

The interval, in seconds, on which the status heartbeat will be triggered.

=item plugins

List of plugins to enable, optionally followed by a reference to the plugin
options.

See L</PLUGINS> below for a list of available plugins.

=item servers

List of servers to enable, optionally followed by a reference to the server
options.

See L</SERVERS> below for a list of available plugins.

=back

=cut

sub new {
    my ($class, %options) = @_;

    my $self = {
        interval => $options{interval} // 1,
        servers  => [],
        plugins  => [],
    };

    bless $self, ref($class) || $class;

    $self->_load_servers( $options{servers} // [] );
    $self->_load_plugins( $options{plugins} // [ qw/ Net Disk Load Clock/ ] );

    # Set up start/stop signals on USR1.. we might not want to get a TERM/CONT
    $self->{sig_stop} = AnyEvent->signal(
        signal => "USR1",
        cb     => sub { undef $self->{beat_cv}; }
    );
    $self->{sig_cont} = AnyEvent->signal(
        signal => "USR2",
        cb     => sub { $self->_setup_heartbeat; }
    );

    # Finally, start things up!
    $self->_setup_heartbeat;

    return $self;
}


#
# Privates
#

sub _load_plugins {
    my ($self, $plugins) = @_;

    my $nplugins = 0;
    while( my $class = shift @$plugins ) {
        my $fullclass =  __PACKAGE__."::Plugin::$class";
        my $opts = ref($plugins->[0]) ? shift @$plugins : {};

        eval("use $fullclass; 1;")
            or warn "Cannot load plugin $class: $@";

        my $plugin = $fullclass->new(
            instance => ++$nplugins,
            %$opts
        );
        push @{ $self->{plugins} }, $plugin;
    }
}


sub _load_servers {
    my ($self, $servers) = @_;

    $servers = [ 'Local' ]
        unless $servers && @$servers;

    while( my $class = shift @$servers ) {
        my $fullclass = __PACKAGE__."::Server::$class";
        my $opts = ref($servers->[0]) ? shift @$servers : {};

        eval("use $fullclass; 1;")
            or die "Cannot load server $class: $@";

        my $server = $fullclass->new( %$opts );
        $server->reg_cb(
            click => sub {
                my ($server, $click) = @_;
                my ($instance, $sub) = split '#', $click->{instance}, 2;

                foreach my $plugin (@{ $self->{plugins} }) {
                    next unless $plugin->{instance} eq $instance;
                    $plugin->click( { %$click, instance => $sub }, $server );
                }

                $self->_heartbeat;
            }
        );

        push @{ $self->{servers} }, $server;
    }
}

# Enable the heartbeat (for init and stop/resume)
sub _setup_heartbeat {
    my $self = shift;

    return if $self->{beat_cv};

    $self->{beat_cv} = AnyEvent->timer(
        interval => $self->{interval},
        cb => sub { $self->_heartbeat }
    );
}

sub _heartbeat {
    my $self = shift;

    my @status;

    foreach my $plugin (@{ $self->{plugins} }) {
        push @status, map {
            {
                %$_,
                instance => $plugin->{instance} . ($_->{instance} ? "#$_->{instance}" : '')
            }
        } $plugin->status;
    }

    $_->status_update( @status )
        foreach ( @{ $self->{servers} } );
}


=head1 PLUGINS

There is a default set of plugins available, each one being a worse example
of broken hacks than the previous. Having said so, here is the list of
supported status plugins:

=over

=item L<Battery|AnyEvent::I3Status::Plugin::Battery>

Provides information about battery levels and times.

=item L<Clock|AnyEvent::I3Status::Plugin::Clock>

Provides date/time information.

=item L<Disk|AnyEvent::I3Status::Plugin::Disk>

Provides information about used space on a partition.

=item L<File|AnyEvent::I3Status::Plugin::File>

Check if a file exists.

This can be used, for example, to check for ssh's ControlMaster sockets.

=item L<Load|AnyEvent::I3Status::Plugin::Load>

Display the average (1m/5m/15m) load values for the system.

=item L<Net|AnyEvent::I3Status::Plugin::Net>

Horrible hack thart tries to parse the output of C<ifconfig> and C<iwconfig>,
and naively scans for some relevant information, makes lots of broken
assumptions, and finally puts togheter potentially misleading information
about your network status.

=item L<PidFile|AnyEvent::I3Status::Plugin::PidFile>

Check if a process is running.

Be aware that the check for the process is done by checking if we can signal
the process, which usually means we need to have the right permissions.

=item L<Temperature|AnyEvent::I3Status::Plugin::Temperature>

Displays temperatures from the C<sensors> command.

It will automatically detect high/max values from the command output and
use red color and urgency if it detects warm conditions.

=item L<WebSocket|AnyEvent::I3Status::Plugin::WebSocket>

Connect to a remote I3Status process which runs a WebSocket server, and
display it's statuses.

Click events are proxied to the remote process as well.

=item L<XRandR|AnyEvent::I3Status::Plugin::XRandR>

Control the display settings via XRandR extension.

Allows some simple auto-detect settings and rotation via click handlers on each detected output.

=item Make your own!

You can also create your own plugins using a very simple interface defined
by L<AnyEvent::I3Status::Plugin> (doc comes with an example plugin).

=back

=head1 SERVERS

I3Status supports different servers in order to report status and receive the click events.

Most of the time, it is enough to use the Local server, meant for running F<p3status>
directly from your F<~i3/config>. If you want to use remote statuses, or plugins which
cannot run properly when executed from i3bar, you can use a the WebSocket server
and the corresponding WebSocket plugin.

=over

=item L<Local|AnyEvent::I3Status::Server::Local>

This is the default server, meant to interface directly with i3bar via STDIN/STDOUT.

=item L<WebSocket|AnyEvent::I3Status::Server::WebSocket>

This server module will listen for connections on a given host/port, and establish
websocket connections. The format used is the same as the i3bar protocol (a JSON
stream), and generally connected to by L<AnyEvent::I3Status::Plugin::WebSocket>.

Options:

=over

=item host

Address to listen to. Defaults to 127.0.0.1, but can be set to 0.0.0.0 to listen to
external connections.

=item port

Port to listen to. Defaults to 22767.

=back

=back

=head1 TODO

=over 4

=item Tests, tests, tests

=item Plugin: add sys monitor (or extend 'load' to allow free mem, i/o load, etc.)

=item Plugin: add network context checker (e.g: detect LANs like work/home/etc.)

=back

=head1 AUTHOR

Quim Rovira, C<< <met at cpan.org> >>

=head1 SUPPORT

You can look for information on the GitHub repository:

L<http://github.com/qrovira/anyevent-i3status/>

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Quim Rovira.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

=cut

1; # End of AnyEvent::I3Status
