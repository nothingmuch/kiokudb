#!/usr/bin/perl -w

use strict;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'KiokuDB::Cmd',
    VERSION_FROM => 'lib/KiokuDB/Cmd.pm',
    INSTALLDIRS  => 'site',
    SIGN         => 1,
    PL_FILES     => { },
    EXE_FILES    => [ grep { /\w$/ } glob("bin/*") ],
    PREREQ_PM    => {
        'KiokuDB' => 0.29,

        # Command line utilities
        'MooseX::Getopt' => 0,
        'App::Cmd' => 0.202,
        'MooseX::App::Cmd' => 0,
        'MooseX::Types::Path::Class' => 0,
        'Proc::InvokeEditor' => 1,
    },
);
