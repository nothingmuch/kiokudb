#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;

use Data::GUID;

use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::Entry';

{
    package Foo;
    use Moose;

    package Bar;
    use Moose;
}

{
    my $l = KiokuDB::LiveObjects->new;

    is_deeply(
        [ $l->live_objects ],
        [ ],
        "no live objects",
    );

    my $x = Foo->new;

    $l->insert( x => $x );

    is_deeply(
        [ $l->live_objects ],
        [ $x ],
        "live object set"
    );

    undef $x;

    is_deeply(
        [ $l->live_objects ],
        [ ],
        "live object set is weak"
    );

    my %objects = (
        ( map { $_ => Foo->new } ( 'a' .. 'z' ) ),
        hash  => { foo => "bar" },
        array => [ 1 .. 3 ],
    );

    $l->insert( %objects );

    is_deeply(
        [ sort $l->live_objects ],
        [ sort values %objects ],
        "live object set"
    );

    $l->remove( 'b', $objects{d} );

    is_deeply(
        [ sort $l->live_objects ],
        [ sort grep { $_ != $objects{d} and $_ != $objects{b} } values %objects ],
        "remove",
    );

    is_deeply( [ $l->ids_to_objects(qw(f array)) ], [ @objects{qw(f array)} ], "id to object" );

    throws_ok { $l->insert( g => $objects{f} ) } qr/already registered/, "double reg under diff ID is an error";

    throws_ok { $l->insert( foo => "bar" ) } qr/not a ref/, "can't register non ref";

    my @objects = ( $objects{n}, $objects{hash} );

    %objects = ();

    is_deeply(
        [ sort $l->live_objects ],
        [ sort @objects ],
        "live object set reduced"
    );

    @objects = ();

    is_deeply(
        [ $l->live_objects ],
        [ ],
        "live object set is now empty"
    );
}

{
    my $l = KiokuDB::LiveObjects->new;

    is( $l->objects_to_ids(Foo->new), undef, "random object has undef ID" );
    is_deeply( [ $l->objects_to_ids(Foo->new, Foo->new) ], [ undef, undef ], "random objects have undef IDs" );
}

{
    my $l = KiokuDB::LiveObjects->new;

    {
        my $entry = KiokuDB::Entry->new( id => "oink" );
        $l->insert_entries($entry);

        is_deeply( [ $l->loaded_ids ], ["oink"], "loaded IDs" );

        is_deeply( [ $l->ids_to_entries("oink") ], [ $entry ], "ids_to_entries" );
    }

    is_deeply( [ $l->loaded_ids ], [], "loaded IDs" );
}

{
    my $l = KiokuDB::LiveObjects->new;

    my $entry = KiokuDB::Entry->new( id => "blah" );
    my $blah = Foo->new;
    $l->insert( $entry => $blah );

    is_deeply( [ $l->objects_to_entries($blah) ], [ $entry ], "objects to entries" );

    is_deeply( [ $l->ids_to_entries("blah") ], [ $entry ], "ids to entries" );
}

