package AnyEvent::I3Status::Plugin::Battery;

use 5.014;
use strict;
use warnings;
use utf8;

use JSON;
use Sys::Apm;
use Linux::Sysfs;

 
sub register {
    my ($class, $i3status, %opts) = @_;

    my $flop = 0;
    my @FLOPS = ('#ff0000','#ffff00');
    my $long = {};

    $i3status->reg_cb(
        heartbeat => $opts{prio} => sub {
            my ($i3status, $status) = @_;

            if( my $apm = Sys::Apm->new ) {
                my $s = { name => "battery" };

                if( $apm->battery_status == 3 ) {
                    $s->{fulltext} = $apm->charge."%";
                }
                else {
                    $s->{fulltext} = $apm->charge."% ".
                        $apm->remaining.$apm->units;
                    # Charge-dependant color
                    $s->{color} = '#ffa500' if $apm->charge < 50;
                    $s->{color} = '#ff0000' if $apm->charge < 20;
                    # Critical status
                    if( $apm->battery_status == 2 ) {
                        $s->{urgent} = JSON::true;
                        $s->{color} = '#ff0000';
                    }
                }

                push @$status, $s;
            }
            elsif( my $power_supply = Linux::Sysfs::Class->open('power_supply') ) {
                my @all;
                foreach my $dev ( $power_supply->get_devices ) {
                    my $type = attrval($dev, 'type');
                    if( $type eq 'Battery' ) {
                        my $status = attrval($dev, 'status');
                        my $full = attrval($dev, 'energy_full') // attrval($dev, 'charge_full');
                        my $now = attrval($dev, 'energy_now') // attrval($dev, 'charge_now');
                        my $rate = attrval($dev, 'power_now') // attrval($dev, 'current_now');
                        my $alarm = attrval($dev, 'alarm');

                        my $percent = sprintf( "%.1f", 100 * $now / ( $full || 1 ) );
                        my $time =
                            $rate && $status eq 'Charging' ? ($full - $now) / $rate :
                            $rate && $status eq 'Discharging' ? $now / $rate :
                            0;
                        my $ftime = sprintf("%d:%02d", int $time, 60 * ($time - int $time));


                        unshift @all, {
                            name => "battery",
                            instance => $dev->name,
                            full_text => "⚡ $percent\%" . ($long->{$dev->name} ? " ($ftime left)" : ""),
                            ( $status eq 'Full' ? ( color => '#00ff00' ) : () ),
                            ( $percent < 50 ? ( color => '#ffa500' ) : () ),
                            ( $percent < 20 ? ( color => '#ff0000' ) : () ),
                            ( $percent < 10 ? ( color => $FLOPS[$flop = ($flop+1) % 2] ) : () ),
                            ( $alarm ? ( urgent => JSON::true ) : () ),
                        };
                    }
                    elsif( $type eq 'Mains' ) {
                        push @all, {
                            name => "battery",
                            instance => "AC",
                            full_text => "⚡ AC"
                        } if attrval($dev,'online');
                    }
                }
                push @$status, @all;
            }
        },
        click => sub {
            my ($i3status, $click) = @_;

            use Data::Dumper;
            warn Dumper $click;

            $long->{$click->{instance}} = !$long->{$click->{instance}}
                if( $click->{name} eq 'battery' );
        }
    );
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

1;
