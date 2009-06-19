#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use ok 'KiokuDB::Test::Digested';

my $foo = KiokuDB::Test::Digested->new(
    foo => "blaitty4",
);

ok( $foo->digest, "got a digest" );

my $bar = KiokuDB::Test::Digested->new(
    bar => "bar",
);

ok( $bar->digest, "got a digest" );

isnt( $foo->digest, $bar->digest, "digests differ" );

my $both = KiokuDB::Test::Digested->new(
    foo => "blaitty4",
    bar => "bar",
);

isnt( $both->digest, $foo->digest, "digests differ" );
isnt( $both->digest, $bar->digest, "digests differ" );

is( $foo->digest, KiokuDB::Test::Digested->new( foo => "blaitty4" )->digest, "digest is the same for new object" );

use Data::Dumper;

like( Dumper($foo->digest_parts), qr/blaitty4/, "contains digest parts" );
