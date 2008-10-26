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
    EXE_FILES    => [ grep { /\w$/ } glob("bin/*") ],
    PREREQ_PM    => {
        'Moose' => 0,
        'MooseX::AttributeHelpers' => 0,
        'MooseX::Types::Path::Class' => 0,

        # Command line utilities
        'MooseX::Getopt' => 0,

        # misc dev shit
        'Check::ISA' => 0,
        'Scalar::Util' => 0,
        'Devel::PartialDump' => '0.06',
        'namespace::clean' => '0.08',

        # Identity is important
        ( eval { require Data::UUID::LibUUID }
            ? ( "Data::UUID::LibUUID" => 0 )
            : ( "Data::UUID"          => 0 ) ),

        # visits are also important
        'Data::Visitor' => '0.20',
        'Tie::ToObject' => 0,

        # scanning and searching
        'Data::Stream::Bulk' => "0.03",

        # live objects
        ( eval { require Variable::Magic } ? ( "Variable::Magic" => "0.24" ) : () ),
        'Hash::Util::FieldHash::Compat' => 0,
        'Scope::Guard' => 0,

        'Set::Object' => '1.26',

        'Module::Pluggable::Object' => 0,
        'Test::use::ok' => 0,
        'Test::Exception' => 0,
        'Test::Memory::Cycle' => 0,
        'Test::More' => 0,
        'Test::TempDir' => 0,

        # used in testing... add skip logic?
        'Class::Accessor' => 0,
        'URI' => 0,
        'DateTime' => 0,

        'Search::GIN' => 0,
    },
);
