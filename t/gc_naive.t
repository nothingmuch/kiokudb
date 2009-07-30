#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use ok 'KiokuDB::GC::Naive';
use ok 'KiokuDB::Entry';
use ok 'KiokuDB::Reference';
use ok 'KiokuDB::Backend::Hash';

use Data::Stream::Bulk::Util qw(bulk);

{
    my $b = KiokuDB::Backend::Hash->new;

    my @entries = KiokuDB::Entry->new( data => [ "foo" ], id => "bar" );

    $b->insert(@entries);

    my $l = KiokuDB::GC::Naive->new( backend => $b );

    is( $l->garbage->size, 1, "one garbage ID" );

    is_deeply( [ $l->garbage->members ], [ "bar" ], "garbage ID is 'bar'" );

    is( $l->root->size, 0, "no root IDs" );
}

{
    my $b = KiokuDB::Backend::Hash->new;

    my @entries = KiokuDB::Entry->new( data => [ KiokuDB::Reference->new( id => "bar" ) ], id => "bar" );

    $b->insert(@entries);

    my $l = KiokuDB::GC::Naive->new( backend => $b );

    is( $l->garbage->size, 1, "one garbage ID (cyclic)" );

    is_deeply( [ $l->garbage->members ], [ "bar" ], "garbage ID is 'bar'" );

    is( $l->root->size, 0, "no root IDs" );
}

{
    my $b = KiokuDB::Backend::Hash->new;

    my @entries = (
        KiokuDB::Entry->new( data => [ KiokuDB::Reference->new( id => "gorch" ) ], id => "bar" ),
        KiokuDB::Entry->new( data => "foo", id => "gorch", root => 1 ),
    );

    $b->insert(@entries);

    my $l = KiokuDB::GC::Naive->new( backend => $b );

    is( $l->garbage->size, 1, "one garbage ID)" );

    is_deeply( [ $l->garbage->members ], [ "bar" ], "garbage ID is 'bar'" );

    is( $l->root->size, 1, "one root ID" );
    is_deeply( [ $l->root->members ], [ "gorch" ], "referenced ID is 'gorch'" );
}


{
    my @entries = (
        KiokuDB::Entry->new(
            data => [ KiokuDB::Reference->new( id => "foo" ) ],
            id => "bar"
        ),
        KiokuDB::Entry->new(
            data => [ KiokuDB::Reference->new( id => "bar" ) ],
            id => "foo"
        ),
        KiokuDB::Entry->new(
            data => [ KiokuDB::Reference->new( id => "bar" ) ],
            id => "parent",
            root => 1,
        ),
    );

    my $b = KiokuDB::Backend::Hash->new;

    $b->insert(@entries);

    foreach my $entries ( \@entries, [ reverse @entries ] ) {
        my $l = KiokuDB::GC::Naive->new( backend => $b, entries => bulk(@$entries) );

        is( $l->garbage->size, 0, "no garbage entries" );

        is( $l->seen->size, 3, "three seen IDs" );

        is_deeply( [ sort $l->seen->members ], [ sort qw(foo bar parent) ], "seen IDs are 'foo', 'bar' and 'parent'" );
    }
}

{
    my @entries = (
        KiokuDB::Entry->new(
            data => [ KiokuDB::Reference->new( id => "foo" ) ],
            id => "bar"
        ),
        KiokuDB::Entry->new(
            data => [ KiokuDB::Reference->new( id => "bar" ) ],
            id => "foo"
        ),
        KiokuDB::Entry->new(
            data => [ ],
            id => "parent",
            root => 1,
        ),
    );

    my $b = KiokuDB::Backend::Hash->new;

    $b->insert(@entries);

    foreach my $entries ( \@entries, [ reverse @entries ] ) {
        my $l = KiokuDB::GC::Naive->new( backend => $b, entries => bulk(@$entries) );

        is( $l->garbage->size, 2, "two garbage entries" );

        is_deeply( [ sort $l->garbage->members ], [ sort "foo", "bar" ], "missing ID is 'gorch'" );

        is( $l->seen->size, 1, "two seen ID" );

        is_deeply( [ sort $l->seen->members ], ['parent'], "seen ID is 'parent'" );
    }
}

{
    my @entries = (
        ( map { KiokuDB::Entry->new( data => [ KiokuDB::Reference->new( id => "foo" ), ], id => $_ ) } 1 .. 1000 ),
        KiokuDB::Entry->new(
            data => [ map { KiokuDB::Reference->new( id => $_ ) } 1 .. 1000 ],
            id => "parent",
            root => 1,
        ),
        KiokuDB::Entry->new(
            id => "foo",
            data => [],
        ),
    );

    my $b = KiokuDB::Backend::Hash->new;

    $b->insert(@entries);

    foreach my $entries ( \@entries, [ reverse @entries ] ) {
        my $l = KiokuDB::GC::Naive->new( backend => $b, entries => bulk(@$entries) );

        is( $l->garbage->size, 0, "no garbage entries" );

        is( $l->seen->size, 1002, "seen IDs" );

        is_deeply( [ sort $l->seen->members ], [ sort qw(foo parent), 1 .. 1000 ], "seen IDs are 'foo', 'bar' and 'parent'" );
    }
}


done_testing;
