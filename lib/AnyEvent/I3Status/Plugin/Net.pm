package AnyEvent::I3Status::Plugin::Net;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;

use Time::HiRes qw/gettimeofday tv_interval/;

=head1 NAME

AnyEvent::I3Status::Plugin::Net - Display status of the network

=head1 SYNOPSIS

    Net => {
        dev          => undef,
        iwconfig_cmd => '/sbin/iwconfig',
        samples      => 5,
        show_details => 0,
        speed_format => '% 6.1f%sBs %s'
        $iface       => {
            show_details => 0
        },
    }

=head1 OPTIONS

=over

=item dev

Devices to display, can be a single string (eg. eth0), an array, or left undefined.

When undefined, if there is a connected interface, that one will be shows, otherwise all will be displayed.

=item iwconfig_cmd

The iwconfig command to use to try to fetch wireless status. Defaults to 'iwconfig'.

In some systems iwconfig will not display power levels or link quality unless it is
run as root. An ugly workaround is to use 'sudo' to solve this.

=item samples

Number of samples to use to average the speed.

=item show_details

Whether or not to display the network speed on the status.

=item speed_format

Format to use for the speed display. Takes 3 arguments: the speed as a float, the unit multiplier (eg. k, M), and the direction (up/down).

=item $iface

Configuration (show_details, by now) can be configured per-interface.

=back

=head2 Click handlers

You can display/hide the network speed clicking on the relevant interface status.

=cut

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        icon => "",
        %opts
    );

    return $self;
}

sub status {
    my ($self) = @_;
    my @status;

    $self->parse_ifconfig;

    if( exists $self->{dev} and $self->{dev} eq 'all' ) {
        push @status, $self->net_status( $_ )
            foreach( keys %{ $self->{ifaces} } );
    }
    elsif( defined $self->{dev} ) {
        push @status,
            map { $self->net_status( $_ ) }
            ( ref $self->{dev} eq "ARRAY" ? @{ $self->{dev} } : $self->{dev} );
    }
    else {
        my @up = sort { $a cmp $b } grep {
            (
                defined $self->{ifaces}{$_}{ipv4} &&
                $self->{ifaces}{$_}{ipv4} !~ m/^127\./
            ) ||
            (
                defined $self->{ifaces}{$_}{ipv6} &&
                $self->{ifaces}{$_}{ipv6_scope} !~ m/^(Link|Host)$/
            )
        } keys %{ $self->{ifaces} };

        if( @up ) {
            push @status, $self->net_status( $_ )
                foreach @up;
        } else {
            push @status, $self->net_status( $_ )
                foreach ( sort { $a cmp $b } keys %{ $self->{ifaces} } );
        }
    }
    
    return @status;
}

sub click {
    my ($self, $click) = @_;

    $self->{$click->{instance}}{show_details} = !$self->{$click->{instance}}{show_details};
}

our @UNITS = (' ', qw/ k M G T P /);
sub human_speed {
    my ($last_sample, $first_sample, $direction, $format) = @_;

    my $delta = $last_sample->{$direction} - $first_sample->{$direction};
    $delta /= tv_interval( $first_sample->{time}, $last_sample->{time} );

    my $exp = int( log($delta||1) / log(1024) );

    return sprintf( $format // '% 6.1f%sBs %s', $delta/(1<<(10*$exp)), $UNITS[$exp], $direction );
}

sub net_status {
    my ($self, $if_name) = @_;
    my $iface = $self->{ifaces}{$if_name};
    my $addr = $iface->{ipv4} // $iface->{ipv6};
    my $up = $iface->{flags} =~ m#RUNNING#;
    my @status = ();

    my $s = {
        name => "net",
        instance => $iface->{name},
        color => ( $up ? '#00ff00' : '#ff0000' ),
        full_text => $iface->{name}.': '.( $addr ? $addr : '-' ),
    };

    my $counts = $self->{$iface->{name}}{speed_samples};
    if( ($self->{show_details} || $self->{$iface->{name}}{show_details}) && $counts && @$counts > 1 && $up ) {
        $s->{full_text} .= ' | '. 
            human_speed( $counts->[-1], $counts->[0], 'D', $self->{speed_format} )
            . ' / ' .
            human_speed( $counts->[-1], $counts->[0], 'U', $self->{speed_format} )
    }

    push @status, $s;

    if( $iface->{wireless} ) {
        my $quality = defined($iface->{link_total}) ?
            int( 100 * $iface->{link_current} / ($iface->{link_total} // 1) ) : undef;

        push @status, {
            name => "net",
            instance => $iface->{name}."/wireless",
            color => ( $iface->{essid} ? '#00ff00' : '#ff0000' ),
            full_text => 'W:'.(
                $iface->{essid} ?
                    ( ($self->{show_details} || $self->{$iface->{name}."/wireless"}{show_details}) ? $iface->{essid} : '') .
                    ( $quality ? ' ('.sprintf('%03d',$quality).'%)' : '' ) :
                    'offline'
            )
        };
    }

    return @status;
}


#
# Lame lame lame
#

my @IFSCAN = (
    # Common debian format
    qr/Link encap:Ethernet\s+HWaddr (?<mac>[a-f0-9:]+)/,
    qr/inet addr:\s*(?<ipv4>[0-9\.]+)/,
    qr/inet addr.*Bcast:(?<ipv4_bcast>[0-9\.]+)/,
    qr/inet addr.*Mask:(?<ipv4_mask>[0-9\.]+)/,
    qr/inet6\s+addr:\s*(?<ipv6>[0-9a-f:]+)\/(?<ipv6_mask>\d+) Scope:(?<ipv6_scope>\w+)/,
    qr/RX\sbytes:\s*(?<rx_bytes>\d+) .* TX\sbytes:\s*(?<tx_bytes>\d+)/,
    qr/(?<flags>(?:\w+\s+)*)\s*MTU:(?<mtu>\d+)\s+Metric:/,
    # New debian format
    qr/inet\s*(?<ipv4>[0-9\.]+)\s+netmask\s+(?<ipv4_mask>[0-9\.]+)/,
    qr/inet6\s+(?<ipv6>[0-9a-f:]+)\s+prefixlen\s+(?<ipv6_mask>\d+)\s+scopeid\s+(?<ipv6_scope>[0-9x<>\w+])/,
    qr/RX packets (?<rx_packets>\d+)\s+bytes\s+(?<rx_bytes>\d+)/,
    qr/TX packets (?<tx_packets>\d+)\s+bytes\s+(?<tx_bytes>\d+)/,
    qr/flags=\d+<(?<flags>(?:\w+(?:,\w+))*)>\s+mtu\s+(?<mtu>\d+)/,
);
my @IWSCAN = (
    qr/ESSID:"(?<essid>[^"]+)"/,
    qr/IEEE (?<wireless>802\.11\w+)/,
    qr/Bit Rate=(?<bit_rate>.*?b\/s)\s+Tx-Power=(?<tx_power>.*dBm)/,
    qr/Link Quality=(?<link_current>\d+)\/(?<link_total>\d+)/,
    qr/Signal level=(?<signal>.*dBm)/,
);

sub parse_ifconfig {
    my ($self) = @_;

    my $ifaces = $self->{ifaces} = {};

    $self->scan_ifwconfig_output('/sbin/ifconfig -a', @IFSCAN);
    $self->scan_ifwconfig_output( ($self->{iwconfig_cmd} // '/sbin/iwconfig').' 2>/dev/null', @IWSCAN);

    delete $ifaces->{lo};

    my $last_check = [gettimeofday];
    foreach( keys %$ifaces ) {
        next if $_ eq 'lo';
        my $counts = $self->{$_}{speed_samples} //= [];
        push @$counts, {
            D => $ifaces->{$_}{rx_bytes},
            U => $ifaces->{$_}{tx_bytes},
            time => $last_check
        };
        shift @$counts if @$counts > ($self->{samples} // 5);
    }

}

sub scan_ifwconfig_output {
    my ($self, $command, @patterns) = @_;

    foreach my $ifchunk ( split "\n\n", `$command` ) {
        my ($name, $first) = $ifchunk =~ /^(\w+)[:\s]+(.*)/
            or next;

        my $if = $self->{ifaces}{$name} //= { name => $name };

        foreach my $pat ( $first, @patterns ) {
            @$if{ keys %+ } = values %+
                if $ifchunk =~ $pat;
        }
    }
}


1;
