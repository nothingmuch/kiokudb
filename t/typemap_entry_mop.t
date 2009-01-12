#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Moose;

use Scalar::Util qw(refaddr reftype blessed);

use ok 'KiokuDB::TypeMap::Entry::MOP';
use ok 'KiokuDB::TypeMap::Resolver';
use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::Linker';
use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::Backend::Hash';
use ok 'KiokuDB::Role::ID';

use constant HAVE_MX_STORAGE => eval { require MooseX::Storage::Meta::Attribute::Trait::DoNotSerialize };

# FIXME lazy trait

{
    package Foo;
    use Moose;

    has foo => ( is => "rw" );

    has bar => ( is => "rw", isa => "Bar" );

    if ( ::HAVE_MX_STORAGE ) {
        has trash => ( is => "ro", traits => [qw(DoNotSerialize)], lazy => 1, default => "lala" );
    }

    package Bar;
    use Moose;

    with qw(KiokuDB::Role::ID);

    sub kiokudb_object_id { shift->id }

    has id => ( is => "ro" );

    has blah => ( is => "rw" );

    package Gorch;
    use Moose::Role;

    has optional => ( is => "rw" );

    package Value;
    use Moose;

    with qw(KiokuDB::Role::Intrinsic);

    has name => ( is => "rw" );
}

my $obj = Foo->new( foo => "HALLO" );

$obj->trash if HAVE_MX_STORAGE;

my $deep = Foo->new( foo => "la", bar => Bar->new( blah => "hai", id => "the_bar" ) );

my $with_anon = Bar->new( blah => "HALLO", id => "runtime_role" );

Gorch->meta->apply($with_anon);

$with_anon->optional("very much");

my $anon_parent = Foo->new( bar => $with_anon );

my $obj_with_value = Foo->new( foo => Value->new( name => "fairly" ) );

foreach my $intrinsic ( 1, 0 ) {
    my $foo_entry = KiokuDB::TypeMap::Entry::MOP->new();
    my $bar_entry = KiokuDB::TypeMap::Entry::MOP->new( $intrinsic ? ( intrinsic => 1 ) : () );

    my $tr = KiokuDB::TypeMap::Resolver->new(
        typemap => KiokuDB::TypeMap->new(
            entries => {
                Foo => $foo_entry,
                Bar => $bar_entry,
            },
        ),
    );

    my $v = KiokuDB::Collapser->new(
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

        my ( $entries, $id ) = $v->collapse( objects => [ $obj ],  );

        my $entry = $entries->{$id};

        is( scalar(keys %$entries), 1, "one entry" );

        isnt( refaddr($entry->data), refaddr($obj), "refaddr doesn't equal" );
        ok( !blessed($entry->data), "entry data is not blessed" );
        is( reftype($entry->data), reftype($obj), "reftype" );

        my $sl = $l->live_objects->new_scope;

        my $expanded = $l->expand_object($entry);

        isa_ok( $expanded, "Foo", "expanded object" );
        isnt( refaddr($expanded), refaddr($obj), "refaddr doesn't equal" );
        isnt( refaddr($expanded), refaddr($entry->data), "refaddr doesn't entry data refaddr" );

        SKIP: {
            skip "MooseX::Storage required for DoNotSerialize test", 2 unless HAVE_MX_STORAGE;
            ok( !exists($entry->data->{trash}), "DoNotSerialize trait honored" );
            is( $expanded->trash, "lala", "trash attr" );
        }

        is_deeply( $expanded, $obj, "is_deeply" );
    }

    {
        my $s = $v->live_objects->new_scope;

        my $bar = $deep->bar;

        my ( $entries, $id ) = $v->collapse( objects => [ $deep ],  );

        my $entry = $entries->{$id};

        if ( $intrinsic ) {
            is( scalar(keys %$entries), 1, "one entry" );
        } else {
            is( scalar(keys %$entries), 2, "two entries" );
            ok( exists($entries->{the_bar}), "custom ID exists" );
            is( $entries->{the_bar}->class, "Bar", "right object" );
        }

        isnt( refaddr($entry->data), refaddr($deep), "refaddr doesn't equal" );
        ok( !blessed($entry->data), "entry data is not blessed" );
        is( reftype($entry->data), reftype($deep), "reftype" );

        if ( $intrinsic ) {
            is_deeply(
                $entry->data,
                {%$deep, bar => KiokuDB::Entry->new( class => "Bar", data => {%$bar}, object => $bar ) },
                "is_deeply"
            );
        } else {
            is_deeply(
                $entry->data,
                {%$deep, bar => KiokuDB::Reference->new( id => "the_bar" ) },
                "is_deeply"
            );
        }

        my $sl = $l->live_objects->new_scope;

        $l->live_objects->insert_entries( values %$entries );

        my $expanded = eval { $l->expand_object($entry) };

        isa_ok( $expanded, "Foo", "expanded object" );
        isnt( refaddr($expanded), refaddr($deep), "refaddr doesn't equal" );
        isnt( refaddr($expanded), refaddr($entry->data), "refaddr doesn't entry data refaddr" );
        is_deeply( $expanded, $deep, "is_deeply" );

        is( $expanded->bar->id, "the_bar", "ID attr preserved even if not used" );
    }

    {
        my $s = $v->live_objects->new_scope;

        my ( $entries, $id ) = $v->collapse( objects => [ $anon_parent ] );

        my $entry = $entries->{$id};

        if ( $intrinsic ) {
            is( scalar(keys %$entries), 1, "one entry" );
        } else {
            is( scalar(keys %$entries), 2, "two entries" );
            ok( exists($entries->{runtime_role}), "custom ID exists" );
            is( $entries->{runtime_role}->class, "Bar", "right object" );
        }

        isnt( refaddr($entry->data), refaddr($anon_parent), "refaddr doesn't equal" );
        ok( !blessed($entry->data), "entry data is not blessed" );
        is( reftype($entry->data), reftype($anon_parent), "reftype" );

        if ( $intrinsic ) {
            is_deeply(
                $entry->data,
                {
                    bar => KiokuDB::Entry->new(
                        class => "Bar",
                        data => {%$with_anon},
                        class_meta => {
                            roles => [qw(Gorch)]
                        },
                        object => $with_anon
                    ),
                },
                "is_deeply"
            );
        } else {
            is_deeply(
                $entry->data,
                {bar => KiokuDB::Reference->new( id => "runtime_role" ) },
                "is_deeply"
            );
        }

        my $sl = $l->live_objects->new_scope;

        $l->live_objects->insert_entries( values %$entries );

        my $expanded = eval { $l->expand_object($entry) };

        isa_ok( $expanded, "Foo", "expanded object" );
        isa_ok( $expanded->bar, "Bar", "inner obeject" );

        is( $expanded->bar->id, "runtime_role", "ID attr preserved even if not used" );

        does_ok( $expanded->bar, "Gorch" );
        ok( $expanded->bar->meta->is_anon_class, "anon class" );
    }

    {
        my $s = $v->live_objects->new_scope;

        my ( $entries, $id ) = $v->collapse( objects => [ $obj_with_value ] );

        my $entry = $entries->{$id};

        is( scalar(keys %$entries), 1, "one entry" );

        isnt( refaddr($entry->data), refaddr($obj_with_value), "refaddr doesn't equal" );
        ok( !blessed($entry->data), "entry data is not blessed" );
        is( reftype($entry->data), reftype($obj_with_value), "reftype" );

        is_deeply(
            $entry->data,
            {
                foo => KiokuDB::Entry->new(
                    class => "Value",
                    data => { %{ $obj_with_value->foo } },
                    object => $obj_with_value->foo,
                ),
            },
            "is_deeply"
        );

        my $sl = $l->live_objects->new_scope;

        $l->live_objects->insert_entries( values %$entries );

        my $expanded = eval { $l->expand_object($entry) };

        isa_ok( $expanded, "Foo", "expanded object" );
        isa_ok( $expanded->foo, "Value", "inner obeject" );
    }
}
