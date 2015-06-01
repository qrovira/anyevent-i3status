package AnyEvent::I3Status;

use 5.014;
use strict;
use warnings;

use parent 'Object::Event';

use AnyEvent;
use AnyEvent::Handle;
use JSON;

=head1 NAME

AnyEvent::I3Status - Status tool for i3bar

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
        output => \*STDOUT, # We'll print the JSON there
        input => \*STDIN    # We'll read click event JSON from there
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
        servers  => [],
        plugins  => [],
    };

    bless $self, ref($class) || $class;

    $self->_load_servers( $options{servers} // [] );
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

=head1 PLUGINS

There is a default set of plugins available, each one being a worse example
of broken hacks than the previous. Having said so, here is the list of
supported status plugins:

=head2 L<Battery|AnyEvent::I3Status::Plugin::Battery>

Provides information about battery levels and times.

=head2 L<Clock|AnyEvent::I3Status::Plugin::Clock>

Provides date/time information.

=head2 L<Disk|AnyEvent::I3Status::Plugin::Disk>

Provides information about used space on a partition.

=head2 L<File|AnyEvent::I3Status::Plugin::File>

Check if a file exists.

This can be used, for example, to check for ssh's ControlMaster sockets.

=head2 L<Load|AnyEvent::I3Status::Plugin::Load>

Display the average (1m/5m/15m) load values for the system.

=head2 L<Net|AnyEvent::I3Status::Plugin::Net>

Horrible hack thart tries to parse the output of C<ifconfig> and C<iwconfig>,
and naively scans for some relevant information, makes lots of broken
assumptions, and finally puts togheter potentially misleading information
about your network status.

=head2 L<PidFile|AnyEvent::I3Status::Plugin::PidFile>

Check if a process is running.

Be aware that the check for the process is done by checking if we can signal
the process, which usually means we either own it, or we are root.

=head2 L<Temperature|AnyEvent::I3Status::Plugin::Temperature>

Displays temperatures from the C<sensors> command.

It will automatically detect high/max values from the command output and
use red color and urgency if it detects warm conditions.

=head2 L<WebSocket|AnyEvent::I3Status::Plugin::WebSocket>

Connect to a remote I3Status process which runs a WebSocket server, and
display it's statuses.

Click events are proxied to the remote process as well.

=head2 Make your own!

You can also create your own plugins using a very simple interface defined
by L<AnyEvent::I3Status::Plugin> (doc comes with an example plugin).

=head1 TODO

=over 4

=item Tests, tests, tests

=item Support multi-bar / multi-handler setups and provide example using mkfifo

=item Allow plugins to do status update bursts (e.g: cache statuses, change only 1 via own timer)

=item Plugin: add sys monitor (or extend 'load' to allow free mem, i/o load, etc.)

=item Plugin: add network context checker (e.g: detect LANs like work/home/etc.)

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
