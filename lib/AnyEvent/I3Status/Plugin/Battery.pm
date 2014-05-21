package AnyEvent::I3Status::Plugin::Battery;

use 5.014;
use strict;
use warnings;

use JSON;
use Sys::Apm;
use Linux::Sysfs;

 
sub register {
    my ($class, $i3status, %opts) = @_;

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
                    my $type = attrval($dev->get_attr('type'));
                    if( $type eq 'Battery' ) {
                        my $status = attrval($dev->get_attr('status'));
                        my ($full,$now,$rate) = map { attrval($dev->get_attr($_)) }
                            qw/ energy_full energy_now power_now /;
                        my $percent = sprintf( "%.1f", 100 * $now / ( $full || 1 ) );
                        my $time = $rate ? ( $status eq 'Charging' ? ($full - $now) : $now ) / $rate : 0;
                        my $ftime = sprintf("%d:%02d", int $time, 60 * ($time - int $time));

                        unshift @all, {
                            name => "battery",
                            instance => $dev->name,
                            full_text => "$percent\% ($ftime left)",
                            ( $percent < 50 ? ( color => '#ffa500' ) : () ),
                            ( $percent < 20 ? ( color => '#ff0000' ) : () ),
                            ( $dev->get_attr('alarm') ? ( urgent => JSON::true ) : () ),
                        };
                    }
                    elsif( $type eq 'Mains' ) {
                        push @all, { name => "battery", instance => "AC", full_text => "AC" }
                            if attrval($dev->get_attr('online'));
                    }
                }
                push @$status, @all;
            }
        }
    );
}

# wtf.. i guess this makes more sense if we were to keep attrs around
sub attrval {
    my ($attr) = @_;
    $attr->can_read || return;
    $attr->read;
    my $val = $attr->value;
    chomp $val;
    return $val;
}

1;
