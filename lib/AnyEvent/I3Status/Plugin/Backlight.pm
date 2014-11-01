package AnyEvent::I3Status::Plugin::Backlight;

use 5.014;
use strict;
use warnings;
use utf8;

use JSON;
use Sys::Apm;
use Linux::Sysfs;

 
sub register {
    my ($class, $i3status, %opts) = @_;
    my $sysfs_class = Linux::Sysfs::Class->open('backlight');
    my %backlights =
        map { $_->name => $_ }
        grep { !$opts{device} || $_->name eq $opts{device} }
        $sysfs_class->get_devices;

    $i3status->reg_cb(
        heartbeat => $opts{prio} => sub {
            my ($i3status, $status) = @_;

            foreach my $backlight ( values %backlights ) {
                my ($current, $max) = map { attrval($backlight,$_) }
                    qw/actual_brightness max_brightness/;
                my $percent = sprintf( "%.1f", 100 * $current / ( $max || 1 ) );

                push @$status, {
                    name => "backlight",
                    instance => $backlight->name,
                    full_text => "☀ $percent",
                }

            }
        },

        click => sub {
            my ($i3status, $click) = @_;
            my $backlight = $backlights{ $click->{instance} } // return;

            if( $click->{button} == 1 ) {
                system("/usr/bin/xbacklight -inc 10%");
            }
            elsif( $click->{button} == 3 ) {
                system("/usr/bin/xbacklight -dec 10%");
            }
            elsif( $click->{button} == 2 ) {
                system("/usr/bin/xbacklight -set 100%");
            }
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
