#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Scalar::Util qw(refaddr blessed);

use ok 'KiokuDB::TypeMap::Entry::Passthrough';
use ok 'KiokuDB::TypeMap::Entry::Naive';
use ok 'KiokuDB::TypeMap::Resolver';
use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::Linker';
use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::Backend::Hash';

{
    package KiokuDB_Test_Foo;
    use Moose;

    has foo => ( is => "rw" );

    package KiokuDB_Test_Bar;
    use Moose;

    has foo => ( is => "rw" );

    package KiokuDB_Test_Gorch;
    use Moose;

    has foo => ( is => "rw" );
}

my $foo = KiokuDB_Test_Foo->new( foo => "HALLO" );
my $bar = KiokuDB_Test_Gorch->new( foo => KiokuDB_Test_Bar->new( foo => "LULZ" ) );

my $p = KiokuDB::TypeMap::Entry::Passthrough->new();
my $pi = KiokuDB::TypeMap::Entry::Passthrough->new( intrinsic => 1 );
my $n = KiokuDB::TypeMap::Entry::Naive->new;

my $tr = KiokuDB::TypeMap::Resolver->new(
    typemap => KiokuDB::TypeMap->new(
        entries => {
            KiokuDB_Test_Foo => $p,
            KiokuDB_Test_Bar => $pi,
        },
    ),
);

my $v = KiokuDB::Collapser->new(
    backend => KiokuDB::Backend::Hash->new,
    live_objects => KiokuDB::LiveObjects->new,
    typemap_resolver => $tr,
);

my $sc = $v->live_objects->new_scope;

my $l = KiokuDB::Linker->new(
    backend => KiokuDB::Backend::Hash->new,
    live_objects => KiokuDB::LiveObjects->new,
    typemap_resolver => $tr,
);

{
    $l->live_objects->clear;
    my $sl = $l->live_objects->new_scope;

    my ( $buffer ) = $v->collapse( objects => [ $foo ],  );

    my $entries = $buffer->_entries;

    is( scalar(keys %$entries), 1, "one entry" );

    my $entry = ( values %$entries )[0];

    isa_ok( $entry->data, "KiokuDB_Test_Foo", "entry data" );
    is( refaddr($entry->data), refaddr($foo), "refaddr equals" );

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "KiokuDB_Test_Foo", "expanded object" );
    is( refaddr($expanded), refaddr($foo), "refaddr equals" );
}

{
    $l->live_objects->clear;
    my $sl = $l->live_objects->new_scope;

    my ( $buffer ) = $v->collapse( objects => [ $bar ],  );

    my $entries = $buffer->_entries;

    is( scalar(keys %$entries), 1, "one entry" );

    my $entry = ( values %$entries )[0];

    is( (blessed($entry->data)||''), '', "entry data not blessed" );
    isa_ok( $entry->data->{foo}, "KiokuDB_Test_Bar", "intrinsic entry" );
    is( refaddr($entry->data->{foo}), refaddr($bar->foo), "refaddr equals" );

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "KiokuDB_Test_Gorch", "expanded object" );
    is( refaddr($expanded->foo), refaddr($bar->foo), "expanded intrinsic refaddr" );

    is_deeply( $expanded->foo, $bar->foo, "eq deeply" );
}

# inflate data edge cases for backwards compat
{
    $l->live_objects->clear;
    my $sl = $l->live_objects->new_scope;

    my ( $buffer ) = $v->collapse( objects => [ $bar ],  );

    my $entries = $buffer->_entries;

    is( scalar(keys %$entries), 1, "one entry" );

    my $entry = ( values %$entries )[0];

    $entry->data->{foo} = KiokuDB::Entry->new( data => $entry->data->{foo} );

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "KiokuDB_Test_Gorch", "expanded object" );
    is( refaddr($expanded->foo), refaddr($bar->foo), "expanded intrinsic refaddr" );

    is_deeply( $expanded->foo, $bar->foo, "eq deeply" );
}

{
    $l->live_objects->clear;
    my $sl = $l->live_objects->new_scope;

    my ( $buffer ) = $v->collapse( objects => [ $bar ],  );

    my $entries = $buffer->_entries;

    is( scalar(keys %$entries), 1, "one entry" );

    my $entry = ( values %$entries )[0];

    $entry->data->{foo} = KiokuDB::Entry->new( data => $entry->data->{foo}, class => ref($entry->data->{foo}) );

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "KiokuDB_Test_Gorch", "expanded object" );
    is( refaddr($expanded->foo), refaddr($bar->foo), "expanded intrinsic refaddr" );

    is_deeply( $expanded->foo, $bar->foo, "eq deeply" );
}


done_testing;
