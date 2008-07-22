#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use Test::More 'no_plan';
use Test::TempDir;

use JSON;

use ok 'MooseX::Storage::Directory::Backend::JSPON';
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

my $b = MooseX::Storage::Directory::Backend::JSPON->new( dir => temp_root, pretty => 1, lock => 0 );

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
    [ $b->exists(map { $_->id } @entries) ],
    [ undef, undef ],
    "none exist yet",
);

$b->insert(@entries);

is_deeply(
    [ $b->exists(map { $_->id } @entries) ],
    [ 1, 1 ],
    "both exist",
);

foreach my $entry ( @entries ) {
    my $file = $b->object_file($entry->id);
    ok( -e $file, "file for " . $entry->id . " exists" );

    local $@;
    my $data = eval { from_json(scalar $file->slurp, { utf8 => 1 }) };
    is( $@, "", "no error loading json" );

    is( ref $data, 'HASH', "hash loaded" );

    is( $data->{id}, $entry->id . '.json', "id is correct" );
}

ok(  -e $b->root_set_file($entries[0]->id), "root is in root set" );
ok( !-e $b->root_set_file($entries[1]->id), "other is not in root set" );

