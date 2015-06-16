package AnyEvent::I3Status::Plugin::Backlight;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;
use utf8;

use JSON;
use Linux::Sysfs;

=head1 NAME

AnyEvent::I3Status::Plugin::Backlight - Display and change monitor backlight setting

=head1 SYNOPSIS

    Backlight => {
        device => "all",
    }

=head1 OPTIONS

=over

=item device

=back

=head2 Click handlers

Left click: increase brightness 10%

Right click: decrease brightness 10%

Middle click: set brightness to 100%

=cut
 
sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        device  => "all",
        %opts
    );

    my $sysfs_class = Linux::Sysfs::Class->open('backlight');
    $self->{backlights} = {
        map { $_->name => $_ }
        $self->{device} eq 'all' ?
        $sysfs_class->get_devices :
        grep { $_->name eq $self->{device} } $sysfs_class->get_devices
    };

    return $self;
}

sub status {
    my ($self) = @_;
    my @status;

    foreach my $backlight ( values %{ $self->{backlights} } ) {
        my ($current, $max) = map { attrval($backlight,$_) }
            qw/actual_brightness max_brightness/;
        my $percent = sprintf( "%.1f", 100 * $current / ( $max || 1 ) );

        push @status, {
            name => "backlight",
            instance => $backlight->name,
            full_text => "☀ $percent",
        }

    }

    return @status;
}

sub click {
    my ($self, $click) = @_;
    my $backlight = $self->{backlights}{ $click->{instance} } // return;

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
