use 5.014;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'AnyEvent::I3Status',
    AUTHOR           => q{Quim Rovira <met@cpan.org>},
    VERSION_FROM     => 'lib/AnyEvent/I3Status.pm',
    ABSTRACT_FROM    => 'lib/AnyEvent/I3Status.pm',
    LICENSE          => 'Artistic_2_0',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.014,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'AnyEvent'          => '7.07',
        'JSON::XS'          => '3.01',
        'Sys::CpuLoad'      => '0.02',
        'Sys::Apm'          => '0.05',
        'Filesys::Df'       => '0.92',
        'Module::Pluggable' => '5.1',
    },
    EXE_FILES => [ 'bin/p3status' ],
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'AnyEvent-I3Status-*' },
);
