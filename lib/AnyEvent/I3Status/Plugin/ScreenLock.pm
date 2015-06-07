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
        timeout  => 120,
        autolock => 1,
        image    => undef,
        color    => '000000',
        %opts
    );

    return $self;
}

sub status {
    my ($self) = @_;
    my $time = GetIdleTime;

    #say STDERR "PID $lock_cv, time $time, timeout is $timeout, autolock is $autolock";

    if( !$self->{lock_cv} && $self->{autolock} && $time > $self->{timeout} ) {
        $self->{lock_cv} = run_cmd(
            [
                "i3lock",
                "-n",
                ( $self->{image} ? ("-i", $self->{image}) : "" ),
                ( $self->{color} ? ("-c", $self->{color}) : "" )
            ],
        );
    }

    return {
        name => "screenlock",
        full_text => "⌛ $self->{timeout}",
        short_text => "⌛",
        color => (
            $self->{autolock} ?
                ($time > $self->{timeout} - 10) ?
                '#ffff00' :
                '#00ff00' :
                '#ffffff'
            ),
    };
}

sub click {
    my ($self, $click) = @_;

    $self->{autolock} = !$self->{autolock};
}

1;
