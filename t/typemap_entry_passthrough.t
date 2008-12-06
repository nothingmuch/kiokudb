#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use Scalar::Util qw(refaddr blessed);

use ok 'KiokuDB::TypeMap::Entry::Passthrough';
use ok 'KiokuDB::TypeMap::Entry::Naive';
use ok 'KiokuDB::TypeMap::Resolver';
use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::Linker';
use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::Backend::Hash';

{
    package Foo;
    use Moose;

    has foo => ( is => "rw" );

    package Bar;
    use Moose;

    has foo => ( is => "rw" );

    package Gorch;
    use Moose;

    has foo => ( is => "rw" );
}

my $foo = Foo->new( foo => "HALLO" );
my $bar = Gorch->new( foo => Bar->new( foo => "LULZ" ) );

my $p = KiokuDB::TypeMap::Entry::Passthrough->new();
my $pi = KiokuDB::TypeMap::Entry::Passthrough->new( intrinsic => 1 );
my $n = KiokuDB::TypeMap::Entry::Naive->new;

my $tr = KiokuDB::TypeMap::Resolver->new(
    typemap => KiokuDB::TypeMap->new(
        entries => {
            Foo => $p,
            Bar => $pi,
        },
    ),
);

my $v = KiokuDB::Collapser->new(
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

    my ( $entries ) = $v->collapse( objects => [ $foo ],  );
    is( scalar(keys %$entries), 1, "one entry" );

    my $entry = ( values %$entries )[0];

    isa_ok( $entry->data, "Foo", "entry data" );
    is( refaddr($entry->data), refaddr($foo), "refaddr equals" );

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "Foo", "expanded object" );
    is( refaddr($expanded), refaddr($foo), "refaddr equals" );
}

{
    $l->live_objects->clear;
    my $sl = $l->live_objects->new_scope;

    my ( $entries ) = $v->collapse( objects => [ $bar ],  );
    is( scalar(keys %$entries), 1, "one entry" );

    my $entry = ( values %$entries )[0];

    is( (blessed($entry->data)||''), '', "entry data not blessed" );
    isa_ok( $entry->data->{foo}, "Bar", "intrinsic entry" );
    is( refaddr($entry->data->{foo}), refaddr($bar->foo), "refaddr equals" );

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "Gorch", "expanded object" );
    is( refaddr($expanded->foo), refaddr($bar->foo), "expanded intrinsic refaddr" );

    is_deeply( $expanded->foo, $bar->foo, "eq deeply" );
}

# inflate data edge cases for backwards compat
{
    $l->live_objects->clear;
    my $sl = $l->live_objects->new_scope;

    my ( $entries ) = $v->collapse( objects => [ $bar ],  );
    is( scalar(keys %$entries), 1, "one entry" );

    my $entry = ( values %$entries )[0];

    $entry->data->{foo} = KiokuDB::Entry->new( data => $entry->data->{foo} );

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "Gorch", "expanded object" );
    is( refaddr($expanded->foo), refaddr($bar->foo), "expanded intrinsic refaddr" );

    is_deeply( $expanded->foo, $bar->foo, "eq deeply" );
}

{
    $l->live_objects->clear;
    my $sl = $l->live_objects->new_scope;

    my ( $entries ) = $v->collapse( objects => [ $bar ],  );
    is( scalar(keys %$entries), 1, "one entry" );

    my $entry = ( values %$entries )[0];

    $entry->data->{foo} = KiokuDB::Entry->new( data => $entry->data->{foo}, class => ref($entry->data->{foo}) );

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "Gorch", "expanded object" );
    is( refaddr($expanded->foo), refaddr($bar->foo), "expanded intrinsic refaddr" );

    is_deeply( $expanded->foo, $bar->foo, "eq deeply" );
}
