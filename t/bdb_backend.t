#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::TempDir;

use Storable qw(thaw);

use ok 'MooseX::Storage::Directory::Backend::BDB';
use ok 'MooseX::Storage::Directory::Collapser';
use ok 'MooseX::Storage::Directory::Resolver';
use ok 'MooseX::Storage::Directory::LiveObjects';

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

my $b = MooseX::Storage::Directory::Backend::BDB->new( dir => temp_root );

my $obj = Foo->new(
    id => "shlomo",
    name => "שלמה",
    friend => Foo->new(
        id => "moshe",
        name => "משה",
    ),
);

$obj->friend->friend($obj);

my $c = MooseX::Storage::Directory::Collapser->new(
    resolver => MooseX::Storage::Directory::Resolver->new(
        live_objects => MooseX::Storage::Directory::LiveObjects->new,   
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

    isa_ok( $data, "MooseX::Storage::Directory::Entry" );
    is( ref $data->data, 'HASH', "hash loaded" );

    is( $data->id, $entry->id, "id is correct" );
}

