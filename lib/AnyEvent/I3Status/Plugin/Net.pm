package AnyEvent::I3Status::Plugin::Net;

use 5.018;
use strict;
use warnings;

sub register {
    my ($class, $i3status, %opts) = @_;

    $i3status->reg_cb(
        heartbeat => $opts{prio} => sub {
            my ($i3status, $status) = @_;

            my %ifaces = parse_ifconfig();
            delete $ifaces{lo};

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
                        $ifaces{$_}{ipv6_scope} !~ m/^Link|Host$/
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
        }
    );
}

sub net_status {
    my ($iface, %opts) = @_;
    my $addr = $iface->{ipv4} // $iface->{ipv6};
    my @status = {
        name => "net",
        instance => $iface->{name},
        color => ( $addr ? '#00ff00' : '#ff0000' ),
        full_text => $iface->{name}.': '.( $addr ? $addr : '-' ),
    };

    if( $iface->{wireless} ) {
        my $quality = int( 100 * $iface->{link_current} / ($iface->{link_total} // 1) );
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
);
my @IWSCAN = (
    qr/ESSID:"(?<essid>[^"]+)"/,
    qr/IEEE (?<wireless>802\.11\w+)/,
    qr/Bit Rate=(?<bit_rate>.*?b\/s)\s+Tx-Power=(?<tx_power>.*dBm)/,
    qr/Link Quality=(?<link_current>\d+)\/(?<link_total>\d+)/,
    qr/Signal level=(?<signal>.*dBm)/,
);

sub parse_ifconfig {
    my %ifaces = ();

    scan_ifwconfig_output('ifconfig -a', \%ifaces, @IFSCAN);
    scan_ifwconfig_output('iwconfig 2>/dev/null', \%ifaces, @IWSCAN);

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
