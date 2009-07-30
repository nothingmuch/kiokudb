#!/usr/bin/perl -w

use strict;

use ExtUtils::MakeMaker;

require 5.008; # utf8 and what not


if ( eval { require KiokuDB::Cmd; 1 } ) {
    open my $fh, "<", "lib/KiokuDB.pm" or die $!;
    while ( <$fh> ) {
        if ( /REQUIRED_CMD_VERSION\s*=/ ) {
            eval $_;
            last;
        }
    }

    unless ( eval { KiokuDB::Cmd->VERSION($::REQUIRED_CMD_VERSION); 1 } ) {
        warn <<WARNING

  *********************************************************
  *                                                       *
  *    Note: your copy of KiokuDB::Cmd is out of date     *
  *                                                       *
  *  Version $::REQUIRED_CMD_VERSION is required by this version of KiokuDB  *
  *                                                       *
  *********************************************************

WARNING
    }
}
WriteMakefile(
    NAME         => 'KiokuDB',
    VERSION_FROM => 'lib/KiokuDB.pm',
    INSTALLDIRS  => 'site',
    SIGN         => 1,
    PL_FILES     => { },
    EXE_FILES    => [ grep { /\w$/ } glob("bin/*") ],
    PREREQ_PM    => {
        'Moose' => 0.83,
        'MooseX::Role::Parameterized' => 0.10,
        #'MooseX::AttributeHelpers' => '0.14',
        'MooseX::Clone' => 0.04,
        'Path::Class' => 0,

        # configure
        'MooseX::YAML' => 0.02,

        # misc dev shit
        'Scalar::Util' => 0,
        #'Devel::PartialDump' => '0.06',
        'namespace::clean' => '0.08',

        # Identity is important
        ( eval { require Data::UUID::LibUUID }
            ? ( "Data::UUID::LibUUID" => 0 )
            : ( "Data::UUID"          => 0 ) ),

        # visits are also important
        'Data::Visitor' => '0.24',
        'Tie::ToObject' => 0,
        'Task::Weaken'  => 0,

        # scanning and searching
        'Data::Stream::Bulk' => "0.07",

        # live objects
        'Hash::Util::FieldHash::Compat' => 0,
        ( eval { require Hash::Util::FieldHash } ? () : (
            # for 5.8 we need some specific versions of fieldhash deps
            'Tie::RefHash::Weak' => '0.09',
            'Variable::Magic'    => '0.24',
        )),
        'Scope::Guard' => 0,

        'Set::Object' => '1.26',

        'Module::Pluggable::Object' => 0,
        'Test::use::ok' => 0,
        'Test::Exception' => 0,
        'Test::More' => 0,

        'Search::GIN' => 0.03,

        'JSON' => 2.12,
        'JSON::XS' => 2.231,
        'YAML::XS' => 0.30,
        'Storable' => 0,

        'IO' => 1.23,

        # closure serializing support
        'PadWalker' => 1.9,

        # Role::ID::Digest
        'Digest::SHA' => 0,
    },
);
