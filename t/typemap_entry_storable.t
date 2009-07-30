#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Scalar::Util qw(refaddr reftype blessed);

use ok 'KiokuDB::TypeMap::Entry::StorableHook';
use ok 'KiokuDB::TypeMap::Resolver';
use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::Linker';
use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::Backend::Hash';

BEGIN { eval 'use Test::Memory::Cycle; 1' or eval 'sub memory_cycle_ok {}' }

{
    package Foo;
    use Moose;

    has foo => ( is => "rw" );

    has bar => ( is => "rw", isa => "Bar", predicate => "has_bar" );

    sub STORABLE_freeze {
        my ( $self, $cloning ) = @_;
        return ( $self->foo, $self->has_bar ? $self->bar : () );
    }

    sub STORABLE_thaw {
        my ( $self, $cloning, $foo, $bar ) = @_;

        $self->foo($foo);
        $self->bar($bar) if ref $bar;
    }

    package Bar;
    use Moose;

    has blah => ( is => "rw" );

    has foo => ( is => "rw", weak_ref => 1 );

    package Gorch;
    use Moose;

    has name => ( is => "rw" );

    sub STORABLE_freeze {
        my ( $self, $cloning );

        return $self->name;
    }

    sub STORABLE_attach {
        my ( $class, $cloning, $name ) = @_;
        $class->new( name => $name );
    }
}

my $obj = Foo->new( foo => "HALLO" );

my $deep = Foo->new( foo => "la", bar => Bar->new( blah => "hai" ) );

my $circular = Foo->new( foo => "oink", bar => Bar->new( blah => "three" ) );
$circular->bar->foo($circular);

my $attach = Gorch->new( name => "blah" );

my $s = KiokuDB::TypeMap::Entry::StorableHook->new;

my $tr = KiokuDB::TypeMap::Resolver->new(
    typemap => KiokuDB::TypeMap->new(
        entries => {
            Foo => $s,
        },
    ),
);

my $v = KiokuDB::Collapser->new(
    backend => KiokuDB::Backend::Hash->new,
    live_objects => KiokuDB::LiveObjects->new,
    typemap_resolver => $tr,
);

my $l = KiokuDB::Linker->new(
    backend => KiokuDB::Backend::Hash->new,
    live_objects => KiokuDB::LiveObjects->new,
    typemap_resolver => $tr,
);

{
    my $s = $v->live_objects->new_scope;

    my ( $buffer ) = $v->collapse( objects => [ $obj ],  );

    my $entries = $buffer->entries;

    is( scalar(keys %$entries), 1, "one entry" );

    my $entry = ( values %$entries )[0];

    isnt( refaddr($entry->data), refaddr($obj), "refaddr doesn't equal" );
    ok( !blessed($entry->data), "entry data is not blessed" );

    my $sl = $l->live_objects->new_scope;

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "Foo", "expanded object" );
    isnt( refaddr($expanded), refaddr($obj), "refaddr doesn't equal" );
    isnt( refaddr($expanded), refaddr($entry->data), "refaddr doesn't entry data refaddr" );
    is_deeply( $expanded, $obj, "is_deeply" );
}

{
    my $s = $v->live_objects->new_scope;

    my $bar = $deep->bar;

    my ( $buffer, $id ) = $v->collapse( objects => [ $deep ],  );

    my $entries = $buffer->entries;

    is( scalar(keys %$entries), 2, "two entries" );

    $l->backend->insert(values %$entries);

    my $entry = $entries->{$id};

    isnt( refaddr($entry->data), refaddr($deep), "refaddr doesn't equal" );
    ok( !blessed($entry->data), "entry data is not blessed" );

    my $sl = $l->live_objects->new_scope;

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "Foo", "expanded object" );
    isnt( refaddr($expanded), refaddr($deep), "refaddr doesn't equal" );
    isnt( refaddr($expanded), refaddr($entry->data), "refaddr doesn't entry data refaddr" );
    is_deeply( $expanded, $deep, "is_deeply" );
}

{
    my $s = $v->live_objects->new_scope;

    my $bar = $deep->bar;

    my ( $buffer, $id ) = $v->collapse( objects => [ $circular ],  );

    my $entries = $buffer->entries;

    is( scalar(keys %$entries), 2, "two entries" );

    $l->backend->insert(values %$entries);

    my $entry = $entries->{$id};

    isnt( refaddr($entry->data), refaddr($circular), "refaddr doesn't equal" );
    ok( !blessed($entry->data), "entry data is not blessed" );

    my $sl = $l->live_objects->new_scope;

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "Foo", "expanded object" );
    isnt( refaddr($expanded), refaddr($circular), "refaddr doesn't equal" );
    isnt( refaddr($expanded), refaddr($entry->data), "refaddr doesn't entry data refaddr" );
    is_deeply( $expanded, $circular, "is_deeply" );

    is( refaddr($expanded->bar->foo), refaddr($expanded), "circular ref" );

    memory_cycle_ok($expanded, "weakened");
}

is_deeply( [ $l->live_objects->live_objects ], [], "no live objects" );

{
    my $s = $v->live_objects->new_scope;

    my ( $buffer ) = $v->collapse( objects => [ $attach ],  );

    my $entries = $buffer->entries;

    is( scalar(keys %$entries), 1, "one entry" );

    my $entry = ( values %$entries )[0];

    isnt( refaddr($entry->data), refaddr($attach), "refaddr doesn't equal" );
    ok( !blessed($entry->data), "entry data is not blessed" );

    my $sl = $l->live_objects->new_scope;

    my $expanded = $l->expand_object($entry);

    isa_ok( $expanded, "Gorch", "expanded object" );
    isnt( refaddr($expanded), refaddr($obj), "refaddr doesn't equal" );
    isnt( refaddr($expanded), refaddr($entry->data), "refaddr doesn't entry data refaddr" );
    is_deeply( $expanded, $attach, "is_deeply" );
}


done_testing;
