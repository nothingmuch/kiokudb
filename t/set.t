#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use ok 'KiokuDB::Set';
use ok 'KiokuDB';
use ok 'KiokuDB::Backend::Hash';

use ok 'KiokuDB::Test::Person';

my $dir = KiokuDB->new(
    backend => KiokuDB::Backend::Hash->new,
);

my @ids = do {
    my @people = map { KiokuDB::Test::Person->new( name => $_ ) } qw(jamima elvis norton);

    my $s = $dir->new_scope;

    $dir->store( @people );
};

{
    my $s = $dir->new_scope;

    my @people = $dir->lookup(@ids);

    my $set = KiokuDB::Set->new(
        dir => $dir,
    );

    is_deeply([ $set->members ], [], "no members");

    $set->insert($ids[0]);

    is_deeply(
        [ $set->members ],
        [ $people[0] ],
        "set vivified",
    );

    ok( $set->loaded, "now marked as loaded" );

    $set->insert( $ids[0] );

    is( $set->size, 1, "inserting ID of live object already in set did not affect set size" );

    ok( $set->loaded, "set still loaded" );

    $set->insert( $ids[2] );

    is( $set->size, 2, "inserting ID of live object" );

    ok( $set->loaded, "set still loaded" );

    is_deeply(
        [ sort $set->members ],
        [ sort @people[0, 2] ],
        "members",
    );
}

{
    my $s = $dir->new_scope;

    my $set = KiokuDB::Set->new(
        dir => $dir,
    );

    is_deeply([ $set->members ], [], "no members");

    $set->insert($ids[0]);

    is_deeply(
        [ $set->members ],
        [ $dir->lookup($ids[0]) ],
        "set vivified",
    );

    ok( $set->loaded, "now marked as loaded" );

    $set->insert( $ids[0] );

    is( $set->size, 1, "inserting ID of live object did not affect set size" );

    ok( $set->loaded, "set still loaded" );

    $set->insert( $ids[2] );

    is( $set->size, 2, "inserting of non live ID" );

    ok( !$set->loaded, "set not loaded" );

    is_deeply(
        [ sort $set->members ],
        [ sort $dir->lookup(@ids[0, 2]) ],
        "members",
    );

    ok( $set->loaded, "now it is loaded" );
}

{
    my $s = $dir->new_scope;

    my $set = KiokuDB::Set->new(
        dir => $dir,
    );

    is_deeply([ $set->members ], [], "no members");

    $set->insert(@ids);

    ok( !$set->loaded, "set not loaded" );

    $set->remove( $dir->lookup($ids[0]) );

    is( $set->size, ( @ids - 1 ), "removed element" );
    ok( !$set->loaded, "set not loaded" );

    is_deeply(
        [ sort $set->members ],
        [ sort $dir->lookup(@ids[1, 2]) ],
        "members",
    );

    ok( $set->loaded, "now it is loaded" );
}

{
    my $s = $dir->new_scope;

    my $set = KiokuDB::Set->new(
        dir => $dir,
    );

    is_deeply([ $set->members ], [], "no members");

    $set->insert(@ids);

    ok( !$set->loaded, "set not loaded" );

    $set->clear;

    is( $set->size, 0, "cleared" );

    ok( $set->loaded, "cleared set is loaded" );
}

{
    my $s = $dir->new_scope;

    my $set = KiokuDB::Set->new(
        dir => $dir,
    );

    is_deeply([ $set->members ], [], "no members");

    $set->insert(@ids[0, 1]);

    ok( !$set->includes($ids[2]), "set does not include $ids[2]" );
    ok( !$set->includes($dir->lookup($ids[2])), "set does not include $ids[2] (obj)" );

    ok( $set->includes($ids[0]), "set includes $ids[0]" );
    ok( $set->includes($dir->lookup($ids[0])), "set includes $ids[0] (obj)" );
}
