#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use URI;
use Set::Object;
use DateTime;
use Path::Class;

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

    has date => (
        isa => "DateTime",
        is  => "ro",
        default => sub { DateTime->now },
    );

    has uri => (
        isa => "URI",
        is  => "ro",
        default => sub { URI->new("http://www.google.com") },
    );

    has stuff => (
        isa => "Path::Class::File",
        is  => "ro",
        default => sub { ::file("foo.jpg") },
    );
}

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
        'DateTime' => KiokuDB::TypeMap::Entry::Passthrough->new(
            intrinsic => 1,
        ),
    },
);

my $k = KiokuDB->new(
    backend => KiokuDB::Backend::Hash->new,
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

    isa_ok( $foo->date, "DateTime" );

    isa_ok( $foo->uri, "URI" );

    isa_ok( $foo->stuff, "Path::Class::File" );

    isa_ok( $foo->foo, "Set::Object" );

    is( $foo->stuff->basename, 'foo.jpg', "value" );

    isa_ok( ( $foo->foo->members )[0], "Foo", 'set enumeration' );
}
