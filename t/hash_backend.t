#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use ok 'KiokuDB::Backend::Hash';
use ok 'KiokuDB::Entry';

my @entries = ( map { KiokuDB::Entry->new($_) }
    { id => 1, root => 1, data => { name => "foo", age => 3 } },
    { id => 2, root => 1, data => { name => "bar", age => 3 } },
    { id => 3, root => 1, data => { name => "gorch", age => 5 } },
    { id => 4, data => { name => "zot", age => 3 } },
);

my $backend = KiokuDB::Backend::Hash->new;

$backend->insert(@entries);

can_ok( $backend, qw(root_entries simple_search) );

my $root_entries = $backend->root_entries;

isa_ok( $root_entries, "Data::Stream::Bulk::Array" );

is_deeply(
    [ sort { $a->id <=> $b->id } $root_entries->all ],
    [ sort { $a->id <=> $b->id } @entries[0 .. 2] ],
    "root set",
);

my $three = $backend->simple_search({ age => 3 });

isa_ok( $three, "Data::Stream::Bulk::Array" );

is_deeply(
    [ sort { $a->id <=> $b->id } $three->all ],
    [ sort { $a->id <=> $b->id } @entries[0 .. 1] ],
    "search",
);


done_testing;
