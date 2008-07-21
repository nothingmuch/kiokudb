#!/usr/bin/perl -w

use strict;

use ExtUtils::MakeMaker;

require 5.008; # utf8 and what not

WriteMakefile(
    NAME         => 'MooseX::Storage::Directory',
    VERSION_FROM => 'lib/MooseX/Storage/Directory.pm',
    INSTALLDIRS  => 'site',
    SIGN         => 1,
    PL_FILES     => { },
    PREREQ_PM    => {
        'Moose' => 0,
        'MooseX::AttributeHelpers' => 0,
        'MooseX::Types::Path::Class' => 0,
        
        # misc dev shit
        'Check::ISA' => 0,
        'Scalar::Util' => 0,
        'Devel::PartialDump' => 0,
        'namespace::clean' => '0.08',

        # Identity is important
        'Data::GUID' => 0,

        # visits are also important
        'Data::Visitor' => '0.18',

        # JSPON backend
        'JSON' => 0,
        'File::NFSLock' => 0,
        'IO::AtomicFile' => 0,

        # live objects
        'Hash::Util::FieldHash::Compat' => 0,
        'Data::Swap' => 0,
        'Scope::Guard' => 0,

        # lazy linker
        'Data::Thunk' => 0,

        'Test::use::ok' => 0,
        'Test::Exception' => 0,
        'Test::Memory::Cycle' => 0,
        'Test::More' => 0,
        'Test::TempDir' => 0,
    },
);

