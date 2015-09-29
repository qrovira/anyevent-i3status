package AnyEvent::I3Status::Plugin::Disk;

use parent 'AnyEvent::I3Status::Plugin';

use 5.014;
use strict;
use warnings;

use Filesys::Df;

=head1 NAME

AnyEvent::I3Status::Plugin::Disk - Display disk usage

=head1 SYNOPSIS

    Disk => {
        path    => '/',
        warn    => '10G',
        hide_ok => 0,
    }

=head1 OPTIONS

=over

=item path

Path (mount point) to check

=item warn

Size from which a warning should be issued

=item hide_ok

Hide the status message if the available free space is above the warn threshold

=back

=cut


our @UNITS = ('', qw/ k M G T P /);
our %UNITS = map { $UNITS[$_] => $_ } 0..$#UNITS;

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(
        hide_ok => 0,
        path => $opts{path} // '/',
        warn => $opts{warn} // '10G',
        icon => "🖪",
        %opts
    );

    return $self;
}

sub status {
    my ($self) = @_;
    my $path = $self->{path};
    my $s = {
        name => "disk",
        instance => $path,
        full_text => $self->_sprintf("$path ?")
    };

    my $df = df($path)
        or return $s;

    my $free = $df->{bavail} * 1024;
    my $hfree = _s2h( $free );
    my $warn = _h2s( $self->{warn} );

    $s->{full_text} = $self->_sprintf("$path $hfree");

    if( $free < $warn ) {
        $s->{color} = '#ff0000';
        $s->{urgent} = JSON::true;
    }

    return ( !$s->{urgent} && $self->{hide_ok} ) ? () : $s;
}


sub _h2s {
    my $human = shift;
    my $size = 0;

    if( $human =~ m#^([\d.]+)([@UNITS])$#i ) {
        $size = $1 * (1 << (10*$UNITS{uc$2}));
    } else {
        $size = $human;
    }

    return $size;
}

sub _s2h {
    my $size = shift;
    my $exp = int( log($size) / log(1024) );
    return sprintf("%.2f%s",$size/(1<<(10*$exp)),$UNITS[$exp]);
}


1;
