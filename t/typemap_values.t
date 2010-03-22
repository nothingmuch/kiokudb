#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Set::Object;
use constant HAVE_URI        => eval { require URI };
use constant HAVE_DATETIME   => eval { require DateTime; require DateTime::Duration };
use constant HAVE_PATH_CLASS => eval { require Path::Class };

use ok "KiokuDB::TypeMap::Entry::Callback";
use ok "KiokuDB::TypeMap::Entry::Passthrough";
use ok "KiokuDB::TypeMap";
use ok "KiokuDB::Backend::Hash";
use ok "KiokuDB";

{
    package Foo;
    use Moose;

    has foo => (
        isa => "Set::Object",
        is  => "ro",
    );

    has scalar_ref => (
        is  => "ro",
        default => sub { my $x = "foo"; \$x },
    );

    has scalar_ref_ref => (
        is  => "ro",
        default => sub { my $x = "foo"; my $y = \$x; \$y },
    );

    if ( ::HAVE_DATETIME ) {
        has date => (
            isa => "DateTime",
            is  => "ro",
            default => sub { DateTime->now },
        );

        has duration => (
            isa => "DateTime::Duration",
            is  => "ro",
            default => sub {
                DateTime::Duration->new(
                    years   => 3,
                    months  => 5,
                    weeks   => 1,
                    days    => 1,
                    hours   => 6,
                    minutes => 15,
                    seconds => 45,
                    nanoseconds => 12000,
                );
            },
        );
    }

    if ( ::HAVE_URI ) {
        has uri => (
            isa => "URI",
            is  => "ro",
            default => sub { URI->new("http://www.google.com") },
        );
    }

    if ( ::HAVE_PATH_CLASS ) {
        has stuff => (
            isa => "Path::Class::File",
            is  => "ro",
            default => sub { Path::Class::file("foo.jpg") },
        );
    }
}


foreach my $format ( qw(memory storable json), eval { require YAML::XS; "yaml" } ) {
    my $t = KiokuDB::TypeMap->new(
        isa_entries => {
            'Set::Object' => KiokuDB::TypeMap::Entry::Callback->new(
                intrinsic => 1,
                collapse => "members",
                expand   => "new",
            ),
            'Path::Class::File' => KiokuDB::TypeMap::Entry::Callback->new(
                intrinsic => 1,
                collapse => "stringify",
                expand   => "new",
            ),
            'Path::Class::Dir' => KiokuDB::TypeMap::Entry::Callback->new(
                intrinsic => 1,
                collapse => "stringify",
                expand   => "new",
            ),
            'URI' => KiokuDB::TypeMap::Entry::Callback->new(
                intrinsic => 1,
                collapse => "as_string",
                expand   => "new",
            ),
            'DateTime' => ( $format eq 'json' )
                ? KiokuDB::TypeMap::Entry::Callback->new( intrinsic => 1, collapse => "epoch", expand => sub { shift->from_epoch( epoch => $_[0] ) } )
                : KiokuDB::TypeMap::Entry::Passthrough->new( intrinsic => 1 ),
        },
    );

    my $k = KiokuDB->new(
        backend => KiokuDB::Backend::Hash->new( serializer => $format ),
        typemap => $t,
    );

    my $id;

    {
        my $foo = Foo->new(
            foo => Set::Object->new(
                Foo->new,
            ),
        );

        my $s = $k->new_scope;

        $id = $k->store($foo);

        ok( $id, "got id" );
    }

    {
        my $s = $k->new_scope;

        my $foo = $k->lookup($id);

        isa_ok( $foo, "Foo" );

        is( ref($foo->scalar_ref), "SCALAR", "scalar ref" );
        is_deeply( $foo->scalar_ref, \"foo", "value" );

        {
            local $TODO = $format eq 'yaml' && "YAML incorrectly thinks scalar refs with weaken backref magic are objects";
            is( ref($foo->scalar_ref_ref), "REF", "scalar ref (REF reftype)" );
            is_deeply( $foo->scalar_ref_ref, \\"foo", "value" );
        }

        if ( HAVE_DATETIME ) {
            isa_ok( $foo->date, "DateTime" );
            isa_ok( $foo->duration, "DateTime::Duration" );
        }

        if ( HAVE_URI ) {
            isa_ok( $foo->uri, "URI" );
        }

        if ( HAVE_PATH_CLASS ) {
            isa_ok( $foo->stuff, "Path::Class::File" );

            is( $foo->stuff->basename, 'foo.jpg', "value" );
        }

        isa_ok( $foo->foo, "Set::Object" );

        isa_ok( ( $foo->foo->members )[0], "Foo", 'set enumeration' );
    }
}


done_testing;
