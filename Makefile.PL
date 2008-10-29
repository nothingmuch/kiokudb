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
        'Moose' => '0.60',
        #'MooseX::AttributeHelpers' => '0.14',
        'MooseX::Types::Path::Class' => 0,

        # Command line utilities
        'MooseX::Getopt' => 0,

        # misc dev shit
        'Scalar::Util' => 0,
        #'Devel::PartialDump' => '0.06',
        'namespace::clean' => '0.08',

        # Identity is important
        ( eval { require Data::UUID::LibUUID }
            ? ( "Data::UUID::LibUUID" => 0 )
            : ( "Data::UUID"          => 0 ) ),

        # visits are also important
        'Data::Visitor' => '0.20',
        'Tie::ToObject' => 0,
        'Task::Weaken'  => 0,

        # scanning and searching
        'Data::Stream::Bulk' => "0.03",

        # live objects
        'Hash::Util::FieldHash::Compat' => 0,
        ( eval { require Hash::Util::FieldHash } ? () : (
            # for 5.8 we need some specific versions of fieldhash deps
            'Tie::RefHash::Weak' => '0.9',
            'Variable::Magic'    => '0.24',
        )),
        'Scope::Guard' => 0,

        'Set::Object' => '1.26',

        'Module::Pluggable::Object' => 0,
        'Test::use::ok' => 0,
        'Test::Exception' => 0,
        'Test::More' => 0,

        # used in testing... add skip logic?
        'URI' => 0,
        'DateTime' => 0,

        'Search::GIN' => 0,
    },
);
