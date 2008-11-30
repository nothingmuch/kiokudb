#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use ok 'KiokuDB::LinkChecker';
use ok 'KiokuDB::Backend::Hash';
use ok 'KiokuDB::Test::Fixture::ObjectGraph';
use ok 'KiokuDB';

my $dir = KiokuDB->new(
    backend => my $backend = KiokuDB::Backend::Hash->new(),
);

my $f = KiokuDB::Test::Fixture::ObjectGraph->new( directory => $dir );

$f->populate;

{
    my $l = KiokuDB::LinkChecker->new( backend => $backend );

    cmp_ok( $l->seen->size, '>', 0, "seen some entries" );
    cmp_ok( $l->missing->size, '==', 0, "no missing entries" );
}

$f->verify; # deletes putin, and removes the ref from Dubya

{
    my $l = KiokuDB::LinkChecker->new( backend => $backend );

    cmp_ok( $l->seen->size, '>', 0, "seen some entries" );
    cmp_ok( $l->missing->size, '==', 0, "no missing entries" );
}

my $deleted_id = do {
    my $s = $dir->new_scope;

    my $dubya = $dir->lookup($f->dubya);

    my $delete = $dubya->friends->[-1];

    $dir->delete($delete);

    $dir->object_to_id($delete);
};

{
    my $l = KiokuDB::LinkChecker->new( backend => $backend );

    cmp_ok( $l->seen->size, '>', 0, "seen some entries" );
    cmp_ok( $l->missing->size, '==', 1, "one missing entry" );
    is_deeply( [ $l->missing->members ], [ $deleted_id ], "ID is correct" );
}
