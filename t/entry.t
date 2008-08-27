#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';


use Storable qw(nfreeze thaw);

use ok 'KiokuDB::Entry';

{
    package Foo;
    use Moose;

    has oi => ( is => "rw" );
}

{
    foreach my $ent (
        KiokuDB::Entry->new(
            id => "foo",
            root => 1,
            class => "Foo",
            data => { oi => "vey" },
        ),
        KiokuDB::Entry->new(
            id => "bar",
            data => [ 1 .. 3 ],
        ),
    ) {
        my $f = nfreeze($ent);

        my $copy = thaw($f);

        is_deeply( $copy, $ent );
    }
}
