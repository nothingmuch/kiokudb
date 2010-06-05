#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use ok 'KiokuDB::Set::Transient';
use ok 'KiokuDB::Set::Deferred';
use ok 'KiokuDB';
use ok 'KiokuDB::Backend::Hash';

use ok 'KiokuDB::TypeMap::Entry::Set';

use ok 'KiokuDB::Test::Person';

my $dir = KiokuDB->new(
    typemap => KiokuDB::TypeMap->new(
        isa_entries => {
            'KiokuDB::Set::Base' => KiokuDB::TypeMap::Entry::Set->new,
        }
    ),
    backend => KiokuDB::Backend::Hash->new,
);

my @ids = do {
    my @people = map { KiokuDB::Test::Person->new( name => $_ ) } qw(jemima elvis norton);

    my $s = $dir->new_scope;

    $dir->store( @people );
};

{
    my $s = $dir->new_scope;

    my @people = $dir->lookup(@ids);

    my $set = KiokuDB::Set::Transient->new( set => Set::Object->new );

    is_deeply([ $set->members ], [], "no members");

    $set->insert($people[0]);

    is_deeply(
        [ $set->members ],
        [ $people[0] ],
        "set members",
    );

    ok( $set->loaded, "set is loaded" );

    $set->insert( $people[0] );

    is( $set->size, 1, "inserting ID of live object already in set did not affect set size" );

    ok( $set->loaded, "set still loaded" );

    $set->insert( $people[2] );

    is( $set->size, 2, "inserting ID of live object" );

    ok( $set->loaded, "set still loaded" );

    is_deeply(
        [ sort $set->members ],
        [ sort @people[0, 2] ],
        "members",
    );

    $set->remove( $people[2] );

    is( $set->size, 1, "removed element" );

    can_ok( $set, "union" );

    foreach my $other ( Set::Object->new( $people[2] ), KiokuDB::Set::Transient->new( set => Set::Object->new( $people[2] ) ) ) {
        my $union = $set->union($other);

        isa_ok( $union, "KiokuDB::Set::Transient", "union" );

        is_deeply(
            [ sort $union->members ],
            [ sort @people[0, 2] ],
            "members",
        );
    }
}


{
    my $s = $dir->new_scope;

    my $set = KiokuDB::Set::Deferred->new( set => Set::Object->new($ids[0]), _linker => $dir->linker );

    ok( !$set->loaded, "set not loaded" );

    is_deeply(
        [ $set->members ],
        [ $dir->lookup($ids[0]) ],
        "set vivified",
    );

    ok( $set->loaded, "now marked as loaded" );

    my @people = $dir->lookup(@ids);

    foreach my $other ( Set::Object->new( $people[2] ), KiokuDB::Set::Transient->new( set => Set::Object->new( $people[2] ) ) ) {
        my $union = $set->union($other);

        isa_ok( $union, "KiokuDB::Set::Loaded", "union" );

        is_deeply(
            [ sort $union->members ],
            [ sort @people[0, 2] ],
            "members",
        );
    }
}

{
    my $s = $dir->new_scope;

    my $set = KiokuDB::Set::Deferred->new( _linker => $dir->linker );

    is( $set->size, 0, "set size is 0" );

    is_deeply([ $set->members ], [], "no members" );

    is( ref($set), "KiokuDB::Set::Deferred", 'calling members on empty set does not load it' );

    $set->insert($dir->lookup(@ids));

    ok( !$set->loaded, "set not loaded by insertion of live objects" );

    $set->remove( $dir->lookup($ids[0]) );

    is( $set->size, ( @ids - 1 ), "removed element" );
    ok( !$set->loaded, "set not loaded" );

    my $other = KiokuDB::Set::Deferred->new( set => Set::Object->new($ids[0]), _linker => $dir->linker );

    isa_ok( my $union = $set->union($other), "KiokuDB::Set::Deferred" );

    ok( !$union->loaded, "union is deferred" );

    is_deeply(
        [ sort $set->members ],
        [ sort $dir->lookup(@ids[1, 2]) ],
        "members",
    );

    ok( $set->loaded, "now it is loaded" );

    is_deeply(
        [ sort $union->members ],
        [ sort $dir->lookup(@ids[0, 1, 2]) ],
        "union",
    );
}

is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

{
    my $s = $dir->new_scope;

    my $set = KiokuDB::Set::Deferred->new( _linker => $dir->linker );

    is_deeply([ $set->members ], [], "no members");

    $set->_objects->insert(@ids);

    ok( !$set->loaded, "set not loaded" );

    $set->clear;

    is( $set->size, 0, "cleared" );

    ok( $set->loaded, "cleared set is loaded" );
}

is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

my $set_id = do {
    my $s = $dir->new_scope;

    my @people = $dir->lookup(@ids);

    $dir->store( KiokuDB::Set::Transient->new( set => Set::Object->new($people[0]) ) );
};

is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

{
    my $s = $dir->new_scope;

    my $set = $dir->lookup($set_id);

    isa_ok( $set, "KiokuDB::Set::Deferred", "deferred set" );

    is( $set->size, 1, "set size" );

    is_deeply(
        [ $set->members ],
        [ $dir->lookup($ids[0]) ],
        "members",
    );

    ok( $set->loaded, "loaded set" );
}

is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

{
    my $s = $dir->new_scope;

    my $set = $dir->lookup($set_id);

    isa_ok( $set, "KiokuDB::Set::Deferred", "deferred set" );

    is( $set->size, 1, "set size" );

    $set->insert( $dir->lookup($ids[2]) );

    is( $set->size, 2, "set size is 2");

    ok( !$set->loaded, "set not loaded" );

    $dir->store($set);

    ok( !$set->loaded, "set not loaded by ->store" );
}

is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

{
    my $s = $dir->new_scope;

    my $set = $dir->lookup($set_id);

    isa_ok( $set, "KiokuDB::Set::Deferred", "deferred set" );

    is( $set->size, 2, "set size" );

    is_deeply(
        [ sort $set->members ],
        [ sort $dir->lookup(@ids[0, 2]) ],
        "members",
    );

    ok( $set->loaded, "loaded set" );
}

is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );


done_testing;
