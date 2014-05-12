# NAME

AnyEvent::I3Status - Generate a JSON stream for i3bar using plugins

# VERSION

Version 0.01

# SYNOPSIS

This module bundles a simple dummy script ready to be used for i3bar
with the current set of plugins.

    $ p3status -c <config_file>

If no config file is specified, ~/.p3status will be tried, and if that
also fails, a default configuration with all available plugins with no
options will be used.

Note that the tool will try to load the configuration via `do(...)`, which
must return a hash of options to use, including the plugin list:

    # Example file ~/.p3status
    [ 'apm', 'net', 'clock' ]


    # Another example
    {
        interval => 0.5,
        plugins  => [ qw/ apm net clock / ]
    }

See ["CONFIG"](#config) below for some more examples, and how to use ad-hoc plugins.

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

# SUBROUTINES/METHODS

## new( %config )

Create a new AnyEvent::I3Status handler.

Options:

- interval

    The interval, in seconds, on which the status heartbeat will be triggered.

- plugins

    List of plugins to enable, optionally followed by a reference to the plugin
    options.

    See [AnyEvent::I3Status::Plugins](https://metacpan.org/pod/AnyEvent::I3Status::Plugins) for a list of available plugins.

- output

    File descriptor to write the status output to. Unless specified, `STDOUT` will
    be used.

- input

    File descriptor to listen to for events coming from the i3wm. Unless specified,
    `STDIN` will be used.

# CONFIG

The config file is loaded via `do(...)`, which means it gets executed as a
perl script. While this is a bit stupid, it allows doing some fancy stuff, like
providing ad-hoc plugins directly on the configuration:

    # Ad-hoc plugin example:
    [
        'net',
        'disk' => { path => '/' },
        myplug => sub { push @$_[1], { full_text => time }; }
    ]

# TODO

- Tests, tests, tests
- Support multi-bar / multi-handler setups
- Allow plugins to do status update bursts (e.g: cache statuses, change only 1 via own timer)
- Turn plugins into less horrible messes
- Plugin: add sys monitor (or extend 'load' to allow free mem, i/o load, etc.)
- Plugin: improve net to show up/down rates
- Plugin: add run\_watch, similar to i3status one
- Plugin: add network context checker (e.g: detect LANs like work/home/etc.)
- Plugin: add VPN / ssh link checkers
- Plugin: add RandR plugin, with click handling to switch modes

# AUTHOR

Quim Rovira, `<met at cpan.org>`

# BUGS

Please report any bugs or feature requests to `bug-anyevent-i3status at rt.cpan.org`, or through
the web interface at [http://rt.cpan.org/NoAuth/ReportBug.html?Queue=AnyEvent-I3Status](http://rt.cpan.org/NoAuth/ReportBug.html?Queue=AnyEvent-I3Status).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AnyEvent::I3Status

You can also look for information at:

- RT: CPAN's request tracker (report bugs here)

    [http://rt.cpan.org/NoAuth/Bugs.html?Dist=AnyEvent-I3Status](http://rt.cpan.org/NoAuth/Bugs.html?Dist=AnyEvent-I3Status)

- GitHub repository

    [http://github.com/qrovira/anyevent-i3status/](http://github.com/qrovira/anyevent-i3status/)

# LICENSE AND COPYRIGHT

Copyright 2014 Quim Rovira.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

[http://www.perlfoundation.org/artistic\_license\_2\_0](http://www.perlfoundation.org/artistic_license_2_0)
