#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use ok 'KiokuDB::LinkChecker';
use ok 'KiokuDB::Entry';
use ok 'KiokuDB::Reference';
use ok 'KiokuDB::Backend::Hash';

use Data::Stream::Bulk::Util qw(bulk);

{
    my $b = KiokuDB::Backend::Hash->new;

    my @entries = KiokuDB::Entry->new( data => [ "foo" ], id => "bar" );

    $b->insert(@entries);

    my $l = KiokuDB::LinkChecker->new( backend => $b );

    is( $l->missing->size, 0, "no missing entries" );

    is( $l->seen->size, 1, "one seen ID" );

    is_deeply( [ $l->seen->members ], [ "bar" ], "seen ID is 'bar'" );

    is( $l->referenced->size, 0, "no referenced IDs" );
}

{
    my $b = KiokuDB::Backend::Hash->new;

    my @entries = KiokuDB::Entry->new( data => [ KiokuDB::Reference->new( id => "bar" ) ], id => "bar" );

    $b->insert(@entries);

    my $l = KiokuDB::LinkChecker->new( backend => $b );

    is( $l->missing->size, 0, "no missing entries" );

    is( $l->seen->size, 1, "one seen ID" );

    is_deeply( [ $l->seen->members ], [ "bar" ], "seen ID is 'bar'" );

    is( $l->referenced->size, 1, "one referenced ID" );

    is_deeply( [ $l->referenced->members ], [ "bar" ], "referenced ID is 'bar'" );
}

{
    my $b = KiokuDB::Backend::Hash->new;

    my @entries = KiokuDB::Entry->new( data => [ KiokuDB::Reference->new( id => "gorch" ) ], id => "bar" );

    $b->insert(@entries);

    my $l = KiokuDB::LinkChecker->new( backend => $b );

    is( $l->missing->size, 1, "one missing entry" );

    is_deeply( [ $l->missing->members ], [ "gorch" ], "missing ID is 'gorch'" );

    is( $l->seen->size, 1, "one seen ID" );

    is_deeply( [ $l->seen->members ], [ "bar" ], "seen ID is 'bar'" );

    is( $l->referenced->size, 1, "one referenced ID" );

    is_deeply( [ $l->referenced->members ], [ "gorch" ], "referenced ID is 'gorch'" );
}


{
    my @entries = (
        KiokuDB::Entry->new(
            data => [ KiokuDB::Reference->new( id => "gorch" ) ],
            id => "bar"
        ),
        KiokuDB::Entry->new(
            data => [ KiokuDB::Reference->new( id => "bar" ) ],
            id => "foo"
        ),
    );

    my $b = KiokuDB::Backend::Hash->new;

    $b->insert(@entries);

    foreach my $entries ( \@entries, [ reverse @entries ] ) {
        my $l = KiokuDB::LinkChecker->new( backend => $b, entries => bulk(@$entries) );

        is( $l->missing->size, 1, "one missing entry" );

        is_deeply( [ $l->missing->members ], [ "gorch" ], "missing ID is 'gorch'" );

        is( $l->seen->size, 2, "two seen IDs" );

        is_deeply( [ sort $l->seen->members ], [ sort qw(foo bar) ], "seen IDs are 'foo', 'bar'" );

        is( $l->referenced->size, 2, "two referenced ID" );

        is_deeply( [ sort $l->referenced->members ], [ sort qw(bar gorch) ], "referenced ID is 'gorch'" );
    }
}


done_testing;
