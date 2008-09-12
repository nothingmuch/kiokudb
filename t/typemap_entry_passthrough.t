#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use Scalar::Util qw(refaddr blessed);

use ok 'KiokuDB::TypeMap::Entry::Passthrough';
use ok 'KiokuDB::TypeMap::Entry::Naive';
use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::Resolver';
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
    resolver => KiokuDB::Resolver->new(
        live_objects => KiokuDB::LiveObjects->new
    ),
    typemap_resolver => $tr,
);

my $sc = $v->resolver->live_objects->new_scope;

my $l = KiokuDB::Linker->new(
    backend => KiokuDB::Backend::Hash->new,
    live_objects => KiokuDB::LiveObjects->new,
    typemap_resolver => $tr,
);

my $sl = $l->live_objects->new_scope;

{
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
    my ( $entries ) = $v->collapse( objects => [ $bar ],  );
    is( scalar(keys %$entries), 1, "one entry" );

    my $entry = ( values %$entries )[0];

    is( (blessed($entry->data)||''), '', "entry data not blessed" );
    isa_ok( $entry->data->{foo}, "KiokuDB::Entry", "intrinsic entry" );
    isa_ok( $entry->data->{foo}->data, "Bar", "intrinsic passthrough entry data" );
    is( refaddr($entry->data->{foo}->data), refaddr($bar->foo), "refaddr equals" );

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "Gorch", "expanded object" );
    is( refaddr($expanded->foo), refaddr($bar->foo), "expanded intrinsic refaddr" );
}
