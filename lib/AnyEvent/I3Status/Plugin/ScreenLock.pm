package AnyEvent::I3Status::Plugin::ScreenLock;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;
use utf8;

use Inline;
use X11::IdleTime;
use AnyEvent::Util qw/run_cmd/;

BEGIN { 
    # Make sure we call Inline's init here, since dynamically
    # loading this class will fail to do it
    Inline::init();
}

=head1 NAME

AnyEvent::I3Status::Plugin::ScreenLock - Control screen locking

=head1 SYNOPSIS

    ScreenLock => {
        timeout  => 120,
        autolock => 1,
        image    => undef,
        color    => '000000',
    }

=head1 OPTIONS

=over

=item timeout

Timeout for an idle session to trigger the screen lock

=item countdown

Show remaining time before locking

=item autolock

Whether autolock is enabled or not

=item image

Image to use as background for the i3lock command

=item color

Color to use as background for the i3lock command

=back

=head2 Click handlers

You can click on the status to disable autolock

=cut


sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        timeout   => 120,
        countdown => 0,
        autolock  => 1,
        image     => undef,
        color     => '000000',
        %opts
    );

    $self->set_timer;

    return $self;
}

sub status {
    my ($self) = @_;

    #say STDERR "PID $lock_cv, time $time, timeout is $timeout, autolock is $autolock";

    return {
        name => "screenlock",
        full_text => ($self->{countdown} ? sprintf("⌛ %03d", $self->{time_left}) : "⌛"),
        short_text => "⌛",
        color => (
            $self->{autolock} ?
                ($self->{time_left} < 20) ?
                '#ffff00' :
                '#00ff00' :
                '#ffffff'
            ),
    };
}

sub click {
    my ($self, $click) = @_;

    if( $click->{button} == 1 ) {
        $self->{autolock} = !$self->{autolock};
    }
    elsif( $click->{button} == 3 ) {
        $self->lock;
    }
}

sub set_timer {
    my $self = shift;

    $self->{time_left} = $self->{timeout};

    $self->{check_lock_cv} = AnyEvent->timer(
        interval => 0.5,
        cb => sub {
            my $time = GetIdleTime;

            $self->{time_left} = $self->{timeout} - $time
                if $self->{time_left} > 0;

            return unless $self->{autolock} && $self->{time_left} <= 0;

            $self->lock;
        }
    );
}

sub lock {
    my $self = shift;

    # last i3lock command did not return yet
    return if $self->{i3lock_cv};

    $self->{i3lock_cv} = run_cmd(
        [
            "i3lock",
            "-n",
            ( $self->{image} ? ("-i", $self->{image}) : "" ),
            ( $self->{color} ? ("-c", $self->{color}) : "" )
        ],
    );

    $self->{i3lock_cv}->cb( sub {
        my $status = shift->recv;
        $self->{i3lock_cv} = undef;

        $self->{time_left} = $self->{timeout};
    } );
}

1;
