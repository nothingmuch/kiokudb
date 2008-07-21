#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;

use Data::GUID;

use ok 'MooseX::Storage::Directory::LiveObjects';

{
    package Foo;
    use Moose;

    package Bar;
    use Moose;
}

{
    my $l = MooseX::Storage::Directory::LiveObjects->new;

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

    my ( $id, $obj ) = ( Data::GUID->new, Foo->new );

    ok( ref($id), "id is an object" );

    $l->insert( $id => $obj );
    
    is_deeply( [ $l->ids_to_objects($id) ], [ $obj ], "fetch by Data::GUID object" );

    is_deeply( [ $l->live_ids ], [ $id->as_string ], "internally IDs are strings" );
}
