#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use Scalar::Util qw(refaddr);

use ok 'KiokuDB::TypeMap::Entry::Passthrough';
use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::Resolver';
use ok 'KiokuDB::Backend::Hash';

{
    package Foo;
    use Moose;

    has foo => ( is => "rw" );
}

my $obj = Foo->new( foo => "HALLO" );

my $p = KiokuDB::TypeMap::Entry::Passthrough->new();

my $tr = KiokuDB::TypeMap::Resolver->new(
    typemap => KiokuDB::TypeMap->new(
        entries => {
            Foo => $p,
        },
    ),
);

my $v = KiokuDB::Collapser->new(
    resolver => KiokuDB::Resolver->new(
        live_objects => KiokuDB::LiveObjects->new
    ),
    typemap_resolver => $tr,
);

my $sc = $v->resolver->live_objects->new_scope;

my $l = KiokuDB::Linker->new(
    backend => KiokuDB::Backend::Hash->new,
    live_objects => KiokuDB::LiveObjects->new,
    typemap_resolver => $tr,
);

my $sl = $l->live_objects->new_scope;

my ( $entries ) = $v->collapse( objects => [ $obj ],  );
is( scalar(keys %$entries), 1, "one entry" );

my $entry = ( values %$entries )[0];

isa_ok( $entry->data, "Foo", "entry data" );
is( refaddr($entry->data), refaddr($obj), "refaddr equals" );

my $expanded = $l->expand_object($entry);

isa_ok( $expanded, "Foo", "expanded object" );
is( refaddr($expanded), refaddr($obj), "refaddr equals" );

