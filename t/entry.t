#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';


use Storable qw(nfreeze thaw);

use ok 'KiokuDB::Entry';
use ok 'KiokuDB::LiveObjects';

{
    package Foo;
    use Moose;

    has oi => ( is => "rw" );
}

my $x = Foo->new( oi => "vey" );
my $l = KiokuDB::LiveObjects->new;

{
    foreach my $ent (
        KiokuDB::Entry->new(
            id => "foo",
            root => 1,
            class => "Foo",
            data => { oi => "vey" },
            object => $x,
        ),
        KiokuDB::Entry->new(
            id => "bar",
            data => [ 1 .. 3 ],
        ),
        KiokuDB::Entry->new(
            id => "goner",
            deleted => 1
        ),
        KiokuDB::Entry->new(
            id => "bar",
            data => [ 1 .. 3 ],
            backend_data => "lalalal",
        ),
        KiokuDB::Entry->new(
            id => "bar",
            data => [ 1 .. 3 ],
            prev => KiokuDB::Entry->new( id => "bar" ),
        ),
    ) {
        my $f = nfreeze($ent);

        my $copy = thaw($f);

        foreach my $transient ( qw(backend_data object prev) ) {
            my $attr = KiokuDB::Entry->meta->find_attribute_by_name($transient);
            ok( !$attr->has_value($copy), "no $transient in copy" );
            $attr->clear_value($ent);
        }

        is_deeply( $copy, $ent, "copy is_deeply orig" );

        is_deeply( thaw(nfreeze($copy)), $copy, "round trip of copy" );
    }
}
