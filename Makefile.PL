#!/usr/bin/perl -w

use strict;
use vars qw($KIOKUDB_VERSION);

use ExtUtils::MakeMaker;

require 5.008;

open my $fh, "<", "lib/KiokuDB/Cmd.pm" or die $!;
while ( <$fh> ) {
    if ( /KIOKUDB_VERSION\s*=/ ) {
        eval $_;
        last;
    }
}

WriteMakefile(
    NAME         => 'KiokuDB::Cmd',
    VERSION_FROM => 'lib/KiokuDB/Cmd.pm',
    INSTALLDIRS  => 'site',
    SIGN         => 1,
    PL_FILES     => { },
    EXE_FILES    => [ grep { /\w$/ } glob("bin/*") ],
    PREREQ_PM    => {
        'KiokuDB' => $KIOKUDB_VERSION,

        # Command line utilities
        'MooseX::Getopt' => 0,
        'App::Cmd' => 0.202,
        'MooseX::App::Cmd' => 0,
        'MooseX::Types::Path::Class' => 0,
        'Proc::InvokeEditor' => 1,
    },
);
