package AnyEvent::I3Status::Plugin::Battery;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;
use utf8;

use JSON;
use Sys::Apm;
use Linux::Sysfs;

 
=head1 NAME

AnyEvent::I3Status::Plugin::Battery - Display battery status

=head1 SYNOPSIS

    Battery => {
        colors  => {
            full => '#ffffff',
            ok => '#ff0000',
            half => '#ff4400',
            warning => '#ffa500',
            critical => ['#ff0000', '#ffff00'], # cycle colors to call for attention
        },
        long         => 0,
    }

=head1 OPTIONS

=over

=item colors

You can specify colors for any of the 'full', 'ok', 'half' (<50%), 'warning' (<25%) and critical (<10%) statuses.

If an array is provided, colors will be cycled on every heartbeat.

=item long

Long format displays time left

=back

=head2 Click handlers

You can switch between long and short format clicking on the status message.

=cut

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        colors => {
            ok => '#00ff00',
            half => '#ff4400',
            warning => '#ffa500',
            critical => [ '#ff0000', '#ffff00' ],
        },
        icon => "⚡",
        %opts
    );

    if( my $apm = Sys::Apm->new ) {
        $self->{_apm} = $apm;
    }
    elsif( my $power_supply = Linux::Sysfs::Class->open('power_supply') ) {
        # We could check devices and keep them around already,
        # but I'm unsure if there can be any changes (eg. battery/docks/etc.),
        # and I'm not concerned about performance at this point..
        $self->{_sysfs} = $power_supply;
    }

    return $self;
}

sub status {
    my $self = shift;
    my @sources = $self->{_apm} ?
        $self->_sources_apm :
        $self->{_sysfs} ?
        $self->_sources_sysfs : ();

    return {
        full_text => "No battery info",
        urgent => 1,
    } unless @sources;

    return map {
        $_->{type} eq 'main' && $_->{status} ? 
            {
                name => "battery",
                instance => "AC",
                full_text => $self->_sprintf("AC")
            } :
        $_->{type} eq 'battery' ?
            {
                name => "battery",
                instance => $_->{name},
                full_text => $self->_sprintf(
                    "$_->{charge}%%%s",
                    (($self->{long}{$_->{name}} // $self->{long}) ? " ($_->{left} left)" : ""),
                ),
                (
                    $_->{charge} < 10 ? $self->_color('critical') :
                    $_->{charge} < 25 ? $self->_color('warning') :
                    $_->{charge} < 50 ? $self->_color('half') :
                    $_->{status} eq 'full' ? $self->_color('full') :
                    $self->_color('ok')
                ),
                ( $_->{alarm} ? ( urgent => JSON::true ) : () ),
            } : ()
    } @sources;
}

sub _sources_apm {
    my $self = shift;
    my $apm = $self->{_apm};
    my @sources;

    push @sources, {
        type => "battery",
        status => $apm->ac_status == 1
    };

    push @sources, {
        type => "battery",
        name => "APM",
        left => $apm->remaining.$apm->units,
        charge => $apm->charge,
        status => $apm->status == 3 ? 'charging' : $apm->{charge} > 95 ? 'full' : 'discharging' ,
        alarm => $apm->status == 2,
    };

    return @sources;
}

sub _sources_sysfs {
    my $self = shift;
    my $power_supply = $self->{_sysfs};
    my @sources;

    foreach my $dev ( $power_supply->get_devices ) {
        my $type = attrval($dev, 'type');
        if( $type eq 'Battery' ) {
            my $status = attrval($dev, 'status');
            my $full = attrval($dev, 'energy_full') // attrval($dev, 'charge_full');
            my $now = attrval($dev, 'energy_now') // attrval($dev, 'charge_now');
            my $rate = attrval($dev, 'power_now') // attrval($dev, 'current_now');
            my $alarm = attrval($dev, 'alarm');

            my $charge = sprintf( "%.1f", 100 * $now / ( $full || 1 ) );
            my $time =
                $rate && $status eq 'Charging' ? ($full - $now) / $rate :
                $rate && $status eq 'Discharging' ? $now / $rate :
                0;
            my $ftime = sprintf("%d:%02d", int $time, 60 * ($time - int $time));


            push @sources, {
                type => "battery",
                name => $dev->name,
                charge => $charge,
                left => $ftime,
                status => lc($status),
                alarm => $alarm,
            }
        }
        elsif( $type eq 'Mains' ) {
            push @sources, {
                type => "main",
                status => attrval($dev, 'online')
            };
        }
    }

    return @sources;
}

sub click {
    my ($self, $click) = @_;

    $self->{long}{$click->{instance}} = !$self->{long}{$click->{instance}};
}

# wtf.. i guess this makes more sense if we were to keep attrs around
sub attrval {
    my ($dev,$attr_name) = @_;

    return unless $dev && $attr_name;

    my $attr = $dev->get_attr($attr_name);
    return unless $attr && $attr->can_read && $attr->read;

    my $val = $attr->value;
    chomp $val;

    return $val;
}

sub _color {
    my $self = shift;
    my $color = shift;

    return () unless $self->{colors}{$color};

    return ( color => $self->{colors}{$color} )
        unless ref $self->{colors}{$color};

    my $current = $self->{_color_flops}{$color} =
        ( ($self->{_color_flops}{$color} // 0) + 1 ) %
        scalar( @{$self->{colors}{$color}} );

    return ( color => $self->{colors}{$color}[$current] );
}

1;
