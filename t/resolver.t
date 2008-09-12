#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use ok 'KiokuDB::Resolver';
use ok 'KiokuDB::LiveObjects';

{
    package Foo;
    use Moose;
}

my $r = KiokuDB::Resolver->new(
    live_objects => KiokuDB::LiveObjects->new
);

{
    my $s = $r->live_objects->new_scope;

    my @objects = map { Foo->new } 1 .. 3;

    my @ids = $r->objects_to_ids(@objects);

    ok( @ids, "IDs assigned" );

    is_deeply(
        [ sort $r->live_objects->live_objects ],
        [ sort @objects ],
        "live object set",
    );

    is( $r->id_to_object($ids[1]), $objects[1], "id to object" );

    is( $r->object_to_id($objects[1]), $ids[1], "id is the same" );

    $r->live_objects->remove($objects[1]);

    isnt( $r->object_to_id($objects[1]), $ids[1], "new ID generated" );
}
