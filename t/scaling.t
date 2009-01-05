#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use ok 'KiokuDB';
use ok 'KiokuDB::Test::Fixture::ObjectGraph';

use Set::Object qw(set);

use Data::Stream::Bulk::Callback;

{
    package KiokuDB::Backend::Hash::Frugal;
    use Moose;

    extends qw(KiokuDB::Backend::Hash);

    override all_entries => sub {
        my $self = shift;

        my @entries = super()->all;

        Data::Stream::Bulk::Callback->new(
            callback => sub {
                if ( @entries ) {
                    return [ shift @entries ];
                } else {
                    return;
                }
            },
        );
    }
}

my $f = KiokuDB::Test::Fixture::ObjectGraph->new;

my $dir = KiokuDB->new(
    backend => KiokuDB::Backend::Hash::Frugal->new,
);

{
    my $s = $dir->new_scope;
    $dir->insert( @{ ($f->create)[0] } );
}

my $count = do {
    my $s = $dir->new_scope;
    scalar $dir->all_objects->all;
};

is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

is( $count, 22, "number of objects in DB" );

{
    my $s = $dir->new_scope;

    my $stream = $dir->all_objects;

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    while ( my $block = $stream->next ) {
        is( scalar(@$block), 1, "one object loaded" );

        my $l = set($dir->live_objects->live_objects);

        ok( $l->includes($block->[0]), "live objects includes object" );

        cmp_ok( $l->size, ">=", 1, "at least one live object " . $l->size );
        cmp_ok( $l->size, "<", $count, "less than the total number of objects" );
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );
}
