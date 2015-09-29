package AnyEvent::I3Status::Plugin::XRandR;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;
use utf8;

use POSIX qw(strftime);

=head1 NAME

AnyEvent::I3Status::Plugin::XRandR - Display and interact with screen settings

=head1 SYNOPSIS

    XRandR => {
        mode        => "short",
        default_pos => "right",
        refresh     => 2,
    }

=head1 OPTIONS

=over

=item mode

Either "short" or "connected", controls how much information is displayed on
the status. If set to "connected" a separate status is displayed for each
screen, which allows to control each output via click handlers.

Left click on the status toggled it between the two modes.

=item refresh

How often to update the screen status. Since it does not change much, by
default it's checked only every 2 seconds.

=item default_pos

Default position to use for non-primary screen auto-configuration.

=back

=head1 CLICK HANDLERS

Left click on the status cycles through the different display modes.

Middle click on a specific output status will tell XRandR to auto-configure
that output.

Right click on a specific output status will cycle the rotation setting
of that output.

=cut

my %ROTATION = (
    normal   => "left",
    left     => "inverted",
    inverted => "right",
    right    => "normal",
);

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        refresh => 2,
        mode => "short",
        default_pos => "right",
        icon => '🖵',
        %opts
    );

    $self->{refresh_cv} = AnyEvent->timer(
        after => 0,
        interval => $self->{refresh},
        cb => sub { $self->parse_xrandr() }
    );

    return $self;
}

sub status {
    my ($self) = @_;

    if( $self->{mode} eq "short" ) {
        my @connected = sort { $a cmp $b } grep { $_->{status} eq "connected" } values %{ $self->{displays}{all} };
        my $primary = $self->{displays}{primary};
        return {
            name => "xrandr",
            instance => "global",
            full_text => $self->_sprintf(join " ", sort { $a cmp $b } map { $_->{display} } @connected),
            short_text => "🖵 ",
        };
    } elsif( $self->{mode} eq "connected" ) {
        return map +{
            name => "xrandr",
            instance => $_->{display},
            full_text => $self->_sprintf(
                "%s %s%s",
                $_->{display},
                $_->{mode} // "off",
                $_->{rotation} ?
                    $_->{rotation} eq 'left' ? ' -90°' :
                    $_->{rotation} eq 'right' ? ' +90°' :
                    $_->{rotation} eq 'inverted' ? ' 180°' : '' : ''
            ),
            short_text => $self->_sprintf("%s",$_->{display}),
        }, grep { $_->{status} eq "connected" } sort { $a->{display} cmp $b->{display} } values %{ $self->{displays}{all} };
    }
}

sub click {
    my ($self, $click) = @_;

    if( $click->{button} == 1 ) {
        $self->{mode} = $self->{mode} eq "short" ? "connected" : "short";
    }
    elsif ( $click->{instance} ne "global" && $click->{button} == 2 ) {
        my $display = $self->{displays}{all}{ $click->{instance} };
        my $primary = $self->{displays}{primary};
        system(
            "xrandr --output $display->{display} --auto".
            (
                $display->{primary} ? "" :
                $self->{default_pos} eq "right" ?
                " --right-of $primary->{display}" :
                " --left-of $primary->{display}"
            )
        );
    }
    elsif ( $click->{instance} ne "global" && $click->{button} == 3 ) {
        my $display = $self->{displays}{all}{ $click->{instance} };
        my $rotation = $ROTATION{ $display->{rotation} // 'normal' };
        system( "xrandr --output $display->{display} --rotate $rotation" );
    }
}

sub parse_xrandr {
    my $self = shift;
    my %displays;
    my $current;

    foreach my $line ( split "\n", `xrandr` ) { 
        if(
            $line =~ m#^
                (?<display>[\w-]+)
                \s+(?:
                    (?<status>disconnected) |
                    (?:
                        (?<status>connected)
                        (?:\s+(?<primary>primary))?
                        (?:\s+
                            (?<mode>\d+x\d+)
                            (?<pos>\+\d+\+\d+)
                        )?
                        (?:\s+(?<rotation>left|right|normal|inverted))?
                    )
                )
                \s+\((?<setting>[^\)]+)\)
                (?:\s+(?<dimensions>\d+mm x \d+mm))?
            #x
        ) {
            $current = $+{display};
            $displays{all}{$current} = { %+ };
            if( $+{primary} ) {
                $displays{primary} = $displays{all}{$current};
            }
        }
        elsif($line =~ m#^\s+(?<mode>\d+x\d+)\s+(?<rates>.*)$#) {
            my $mode = $+{mode};
            my @rates = split /\s+/, $+{rates};
            foreach my $rate ( @rates ) {
                my $preferred = $rate =~ s#\+##;
                my $active = $rate =~ s#\*##;

                push @{ $displays{all}{$current}{modes}{$mode} }, $rate;

                if($preferred) {
                    $displays{all}{$current}{preferred} = {
                        mode => $mode,
                        rate => $rate
                    };
                }
                if($active) {
                    $displays{all}{$current}{active} = {
                        mode => $mode,
                        rate => $rate
                    };
                }
            }
        }
    }

    $self->{displays} = \%displays;
}

1;
