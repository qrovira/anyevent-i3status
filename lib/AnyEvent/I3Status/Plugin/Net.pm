package AnyEvent::I3Status::Plugin::Net;

use 5.014;
use strict;
use warnings;

use Time::HiRes qw/gettimeofday tv_interval/;

my %speed_samples;

sub register {
    my ($class, $i3status, %opts) = @_;

    $i3status->reg_cb(
        heartbeat => $opts{prio} => sub {
            my ($i3status, $status) = @_;

            my %ifaces = parse_ifconfig(%opts);
            delete $ifaces{lo};

            my $last_check = [gettimeofday];
            foreach( keys %ifaces ) {
                my $counts = $speed_samples{$_} //= [];
                push @$counts, {
                    D => $ifaces{$_}{rx_bytes},
                    U => $ifaces{$_}{tx_bytes},
                    time => $last_check
                };
                shift @$counts if @$counts > ($opts{samples} // 5);
            }

            if( exists $opts{dev} and $opts{dev} eq 'all' ) {
                push @$status, net_status( $ifaces{ $_ }, %opts )
                    foreach( keys %ifaces );
            }
            elsif( exists $opts{dev} ) {
                push @$status, net_status( $ifaces{ $opts{dev} }, %opts );
            }
            else {
                my @up = sort { $a cmp $b } grep {
                    (
                        defined $ifaces{$_}{ipv4} &&
                        $ifaces{$_}{ipv4} !~ m/^127\./
                    ) ||
                    (
                        defined $ifaces{$_}{ipv6} &&
                        $ifaces{$_}{ipv6_scope} !~ m/^(Link|Host)$/
                    )
                } keys %ifaces;

                if( @up ) {
                    push @$status, net_status( $ifaces{ $_ }, %opts )
                        foreach @up;
                } else {
                    push @$status, net_status( $ifaces{ $_ }, %opts )
                        foreach ( sort { $a cmp $b } keys %ifaces );
                }
            }
        },
        click => sub {
            my ($i3status, $click) = @_;

            $opts{$click->{instance}}{show_speed} = !$opts{$click->{instance}}{show_speed}
                if( $click->{name} eq 'net' );
        }
    );
}

our @UNITS = (' ', qw/ k M G T P /);
sub human_speed {
    my ($last_sample, $first_sample, $direction, $format) = @_;

    my $delta = $last_sample->{$direction} - $first_sample->{$direction};
    $delta /= tv_interval( $first_sample->{time}, $last_sample->{time} );

    my $exp = 0;
    do { $delta /= 1024; $exp++ } while( $delta > 1000 );

    return sprintf( $format // '% 6.1f%sBs %s', $delta, $UNITS[$exp], $direction );
}

sub net_status {
    my ($iface, %opts) = @_;
    my $addr = $iface->{ipv4} // $iface->{ipv6};
    my $up = $iface->{flags} =~ m#RUNNING#;
    my @status = ();

    my $s = {
        name => "net",
        instance => $iface->{name},
        color => ( $up ? '#00ff00' : '#ff0000' ),
        full_text => $iface->{name}.': '.( $addr ? $addr : '-' ),
    };

    my $counts = $speed_samples{$iface->{name}};
    if( ($opts{show_speed} || $opts{$iface->{name}}{show_speed}) && $counts && @$counts > 1 && $up ) {
        $s->{full_text} .= ' | '. 
            human_speed( $counts->[-1], $counts->[0], 'D', $opts{speed_format} )
            . ' / ' .
            human_speed( $counts->[-1], $counts->[0], 'U', $opts{speed_format} )
    }

    push @status, $s;

    if( $iface->{wireless} ) {
        my $quality = defined($iface->{link_total}) ?
            int( 100 * $iface->{link_current} / ($iface->{link_total} // 1) ) : undef;

        push @status, {
            name => "net",
            instance => $iface->{name}."/wireless",
            color => ( $iface->{essid} ? '#00ff00' : '#ff0000' ),
            full_text => 'W: '.(
                $iface->{essid} ?
                    $iface->{essid} .
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
    qr/Link encap:Ethernet\s+HWaddr (?<mac>[a-f0-9:]+)/,
    qr/inet addr:\s*(?<ipv4>[0-9\.]+)/,
    qr/inet addr.*Bcast:(?<ipv4_bcast>[0-9\.]+)/,
    qr/inet addr.*Mask:(?<ipv4_mask>[0-9\.]+)/,
    qr/inet6\s+addr:\s*(?<ipv6>[0-9a-f:]+)\/(?<ipv6_mask>\d+) Scope:(?<ipv6_scope>\w+)/,
    qr/RX\sbytes:\s*(?<rx_bytes>\d+) .* TX\sbytes:\s*(?<tx_bytes>\d+)/,
    qr/(?<flags>(?:\w+\s+)*)\s*MTU:(?<mtu>\d+)\s+Metric:/,
);
my @IWSCAN = (
    qr/ESSID:"(?<essid>[^"]+)"/,
    qr/IEEE (?<wireless>802\.11\w+)/,
    qr/Bit Rate=(?<bit_rate>.*?b\/s)\s+Tx-Power=(?<tx_power>.*dBm)/,
    qr/Link Quality=(?<link_current>\d+)\/(?<link_total>\d+)/,
    qr/Signal level=(?<signal>.*dBm)/,
);

sub parse_ifconfig {
    my %opts = @_;
    my %ifaces = ();

    scan_ifwconfig_output('/sbin/ifconfig -a', \%ifaces, @IFSCAN);
    scan_ifwconfig_output( ($opts{iwconfig_cmd} // '/sbin/iwconfig').' 2>/dev/null', \%ifaces, @IWSCAN);

    return %ifaces;
}

sub scan_ifwconfig_output {
    my ($command, $output, @patterns) = @_;

    foreach my $ifchunk ( split "\n\n", `$command` ) {
        my ($name) = $ifchunk =~ /^(\w+)\s/
            or next;

        my $if = $output->{$name} //= { name => $name };

        foreach my $pat ( @patterns ) {
            @$if{ keys %+ } = values %+
                if $ifchunk =~ $pat;
        }
    }

}


1;
