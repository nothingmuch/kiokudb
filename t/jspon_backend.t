#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use Test::More 'no_plan';
use Test::TempDir;

use Storable qw(dclone);
use JSON;

use ok 'KiokuDB::Backend::JSPON';
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

my $b = KiokuDB::Backend::JSPON->new( dir => temp_root, pretty => 1, lock => 0 );

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
        live_objects => my $lo = KiokuDB::LiveObjects->new,
    ),
    typemap_resolver => KiokuDB::TypeMap::Resolver->new(
        typemap => KiokuDB::TypeMap->new
    ),
);

my $s = $lo->new_scope;

my @entries = $c->collapse_objects($obj, { blah => "blah" });

$entries[0]->root(1);
$entries[1]->root(1);

is( scalar(@entries), 3, "two entries" );

is_deeply(
    [ map { !$_ } $b->exists(map { $_->id } @entries) ],
    [ 1, 1, 1 ],
    "none exist yet",
);

$b->insert(@entries);

is_deeply(
    [ $b->exists(map { $_->id } @entries) ],
    [ 1, 1, 1 ],
    "both exist",
);

foreach my $entry ( @entries ) {
    my $file = $b->object_file($entry->id);
    ok( -e $file, "file for " . $b->uuid_to_string($entry->id) . " exists" );

    local $@;
    my $data = eval { from_json(scalar $file->slurp, { utf8 => 1 }) };
    is( $@, "", "no error loading json" );

    is( ref $data, 'HASH', "hash loaded" );

    is( $b->parse_uid($data->{id}), $entry->id, "id is correct" );
}

ok(  -e $b->root_set_file($entries[0]->id), "root is in root set" );
ok(  -e $b->root_set_file($entries[1]->id), "root is in root set" );
ok( !-e $b->root_set_file($entries[2]->id), "child is not in root set" );


my @clones = map { dclone($_) } @entries;

is_deeply(
    [ $b->get(map { $_->id } @entries) ],
    [ @clones ],
    "loaded",
);

$b->delete($entries[0]->id);


is_deeply(
    [ map { !$_ } $b->exists(map { $_->id } @entries) ],
    [ 1, !1, !1 ],
    "deleted",
);
