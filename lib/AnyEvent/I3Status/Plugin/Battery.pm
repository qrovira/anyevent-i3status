package AnyEvent::I3Status::Plugin::Battery;

use 5.018;
use strict;
use warnings;

use JSON;
use Sys::Apm;

 
sub register {
    my ($class, $status, %opts) = @_;

    $status->reg_cb( heartbeat => $opts{prio} => sub {
        my ($self, $status) = @_;

        my $apm = Sys::Apm->new
            or return;

        $apm->battery_status == 4
            or return;

        my $s = {
            name => "apm",
            $apm->battery_status == 2 ? ( urgent => JSON::true ) : ()
        };

        if( $apm->battery_status == 3 ) {
            $s->{full_text} = $apm->charge."%";
        }
        else {
            $s->{full_text} = $apm->charge."% ".$apm->remaining.$apm->units;

            $s->{color} = '#ffa500'
                if $apm->charge < 50;

            $s->{color} = '#ff0000'
                if $apm->charge < 20;
        }

        push @$status, $s;
    } );
}

1;
