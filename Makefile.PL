#!/usr/bin/perl -w

use strict;

use ExtUtils::MakeMaker;

require 5.008; # utf8 and what not

WriteMakefile(
    NAME         => 'KiokuDB',
    VERSION_FROM => 'lib/KiokuDB.pm',
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
        'Devel::PartialDump' => '0.06',
        'namespace::clean' => '0.08',

        # Identity is important
        'Data::GUID' => 0,
        #'Data::UUID::LibUUID' => 0, # reccomended

        # visits are also important
        'Data::Visitor' => '0.20',
        'Tie::ToObject' => 0,

        # scanning and searching
        'Data::Stream::Bulk' => "0.03",

        # JSPON backend
        'JSON' => 0,
        'File::NFSLock' => 0,
        'IO::AtomicFile' => 0,
        'Path::Class' => 0,
        'MooseX::Types::Path::Class' => 0,

        # CouchDB backend
        'Net::CouchDb' => 0,

        'BerkeleyDB::Manager' => 0,

        # live objects
        'Hash::Util::FieldHash::Compat' => 0,
        'Scope::Guard' => 0,

        'Set::Object' => 0,

        'Test::use::ok' => 0,
        'Test::Exception' => 0,
        'Test::Memory::Cycle' => 0,
        'Test::More' => 0,
        'Test::TempDir' => 0,

        # used in testing
        'Class::Accessor' => 0,
        'URI' => 0,
    },
);
