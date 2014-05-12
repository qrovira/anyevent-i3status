package AnyEvent::I3Status::Plugins;

use 5.018;
use strict;
use warnings;
 
1;

=head1 PLUGINS

There is a default set of plugins available, each one being a worse example
of broken hacks than the previous. Having said so, here is the list of
supported status plugins:



=head2 Battery

Provides information about battery levels and times.



=head2 Clock

Provides date/time information.

=head3 Options

=over

=item format

Format string as passed to strftime

=item format_short

Format string as passed to strftime, used for the "short" version of the
status, which will be used on cluttered bars.

=back



=head2 Disk

Provides information about used space on a partition.

Is uses L<Filesys::Df>, and does not account for reserved blocks, which means
the percentage reflects user-available blocks.

=head3 Options

=over

=item path

Path that points to where the partition is mounted.

=item warn

A threshold (% full) on which to alert using red color & urgency on the bar. Defaults to 95%.

=back



=head2 Load

Display the average (1m/5m/15m) load values for the system.



=head2 Net

Horrible hack thart tries to parse the output of C<ifconfig> and C<iwconfig>,
and naively scans for some relevant information, makes lots of broken
assumptions, and finally puts togheter potentially misleading information
about your network status.

=head3 Options

=over

=item dev

Device to report network status on.

When it's not specified, it'll try to report on first non-local, connected interface.

When set to B<all>, a status block will be added for each found interface.

=back




=head2 Temperature

Displays temperatures from the C<sensors> command.

It will automatically detect high/max values from the command output and
use red color and urgency if it detects warm conditions.

=head3 Options

=over

=item sensor

The sensor to report the temperature from.

When it's not specified, it will report on the warmest sensor found.

When set to B<all>, a status block will be added for each found sensor.

=back



=head1 CREATING PLUGINS

The L<AnyEvent::I3Status> module is based on L<Object::Event>, essentially
triggers a I<hearbeat> event every C<$interval> seconds, to which plugins
are expected to be subscribed.

In the future, other additional events might be added, for example, to
provide click event handling.

Plugins for L<AnyEvent::I3Status> are rather dummy modules that only need
to provide a single C<register> method, where they can subscribe to the
handler's events. They should use the priority provided on the
C<$opts{prio}> option, to preserve the user-configured status order.

    sub register {
        my ($class, $status, %opts) = @_;
    
        $status->reg_cb( [ heartbeat => $opts{prio} ] => sub {
            my ($handler, $status) = @_;

            push @$status, {
                name => "some_name",
                instance => $opts{main_param},
                color => '#ef3c7b',
                full_text => 'Hello kitty',
            };
        } );
    }

=head2 EVENTS

The following events are triggered on the handler instance:

=over

=item heartbeat ( $handler, $status )

Basic heartbeat event which fires every C<$interval> seconds, telling the
plugins to generate their status blocks.

The current list of statuses is passed on C<$status>, to which the plugin
can append or mangle any of the already generated statuses.

=item click ( $handler, $click_event )

If supported by your version of i3bar, this event is triggered when i3bar
signals a user click. On C<$click_event> you can find the C<name>,
C<instance>, C<button>, C<x> and C<w> for the event as provided
according to the i3bar protocol.

=head2 I3WM DOCS

See L<I3WM documentation|http://i3wm.org/docs/i3bar-protocol.html> for more
details on which fields can be used to describe status blocks.

=head1 ACKNOWLEDGEMENTS

Hello Kitty is a trademark of Sanrio.

=cut
