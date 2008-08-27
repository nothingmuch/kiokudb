#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use Storable qw(nfreeze thaw);

use ok 'KiokuDB::Reference';

my $ref = KiokuDB::Reference->new(
    id => "foo",
    weak => 1,
);

my $f = nfreeze($ref);

my $copy = thaw($f);

is_deeply( $copy, $ref );

