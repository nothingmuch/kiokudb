#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use Storable qw(nfreeze thaw);

use ok 'KiokuDB::Reference';

foreach my $id (
    "foo",
    123,
    "la-la",
    "3B19C598-E873-4C65-80BA-0D1C4E961DC9",
    "9170dc3d7a22403e11ff4c8aa1cd14d20c0ebf65",
    pack("H*", "9170dc3d7a22403e11ff4c8aa1cd14d20c0ebf65"),
    "foo,bar",
) {
    foreach my $weak ( 1, 0, '', undef ) {
        my $ref = KiokuDB::Reference->new(
            id => $id,
            defined($weak) ? ( weak => $weak ) : (),
        );

        is( $ref->id, $id, "ID in constructor" );

        my $f = nfreeze($ref);

        isa_ok( my $copy = thaw($f), "KiokuDB::Reference", "thaw" );

        is( $copy->id, $id, "ID after thaw" );

        is_deeply( $copy, $ref, "eq deeply" );
    }
}
