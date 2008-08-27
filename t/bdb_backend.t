#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::TempDir;

use Storable qw(thaw);

use ok 'KiokuDB::Backend::BDB';
use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::Resolver';
use ok 'KiokuDB::LiveObjects';

{
    package Foo;
    use Moose;

    has id => (
        isa => "Str",
        is  => "rw",
    );

    has name => (
        isa => "Str",
        is  => "rw",
    );

    has friend => (
        isa => "Foo",
        is  => "rw",
    );
}

my $b = KiokuDB::Backend::BDB->new( dir => temp_root, binary_uuids => 1 );

my $obj = Foo->new(
    id => "shlomo",
    name => "שלמה",
    friend => Foo->new(
        id => "moshe",
        name => "משה",
    ),
);

$obj->friend->friend($obj);

my $c = KiokuDB::Collapser->new(
    resolver => KiokuDB::Resolver->new(
        live_objects => KiokuDB::LiveObjects->new,
    ),
);

my @entries = $c->collapse_objects($obj);

is( scalar(@entries), 2, "two entries" );

is_deeply(
    [ map { !!$_ } $b->exists(map { $_->id } @entries) ],
    [ '', '' ],
    "none exist yet",
);

$b->insert(@entries);

is_deeply(
    [ $b->exists(map { $_->id } @entries) ],
    [ 1, 1 ],
    "both exist",
);

foreach my $entry ( @entries ) {
    ok( $b->dbm->db_get($entry->id, my $data) == 0, "got from db" );

    isa_ok( $data, "KiokuDB::Entry" );
    is( ref $data->data, 'HASH', "hash loaded" );

    is( $data->id, $entry->id, "id is correct" );
}

