package AnyEvent::I3Status::Plugin;

use 5.014;
use strict;
use warnings;

=head1 NAME

AnyEvent::I3Status::Plugin::WebSocket - Connect to another p3status via websockets and display its statuses.

=head1 SYNOPSIS

    package AnyEvent::I3Status::Plugin::MyPlugin;
    use parent 'AnyEvent::I3Status::Plugin';

    sub new {
        my ($class, %opts) = @_;
        my $self = $class->SUPER::new(
            opt_1        => "default value",
            %opts
        );

        return $self;
    }

    sub status {
        my $self = shift;

        # ...

        return @statuses;
    }

    sub click {
        my ($self, $click, $server) = @_;

        # ...
    }

=head1 CREATING PLUGINS

The L<AnyEvent::I3Status> module triggers a I<hearbeat> event every
C<$interval> seconds at which point it will collect all the plugin
statuses by calling the C<status> method on each plugin, which can
return one or many status hashes (see the i3bar protocol docs for
a good specification of what's possible).

Plugins should avoid doing heavy or slow operation during this call,
but instead use any async fetching provided by AnyEvent modules.

Plugins can also implement the C<click> method, which will recive
any click events on any of the plugin's generated statuses (deciding
which one is up to the plugin, via name or instance attributes).

=head2 I3WM DOCS

See L<I3WM documentation|http://i3wm.org/docs/i3bar-protocol.html> for more
details on which fields can be used to describe status blocks.

=head1 ACKNOWLEDGEMENTS

Hello Kitty is a trademark of Sanrio.

=cut

sub new {
    my ($proto, %opts) = @_;

    my $self = { %opts };

    bless( $self, ref($proto) || $proto );

    return $self;
}

sub status {
    my ($self) = @_;

    return ();
}

sub click {
    my ($self) = @_;
}

1;
