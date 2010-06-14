#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Moose;

use Scalar::Util qw(refaddr reftype blessed);
use Try::Tiny;

use ok 'KiokuDB::TypeMap::Entry::MOP';
use ok 'KiokuDB::TypeMap::Resolver';
use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::Linker';
use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::Backend::Hash';
use ok 'KiokuDB::Role::ID';

use constant HAVE_MX_STORAGE => try { require MooseX::Storage::Meta::Attribute::Trait::DoNotSerialize };

# FIXME lazy trait

{
    package KiokuDB_Test_Foo;
    use Moose;

    our $VERSION = "0.03";

    has foo => ( is => "rw" );

    has bar => ( is => "rw", isa => "KiokuDB_Test_Bar" );

    if ( ::HAVE_MX_STORAGE ) {
        has trash => ( is => "ro", traits => [qw(DoNotSerialize)], lazy => 1, default => "lala" );
    }

    has junk => ( is => "ro", traits => [qw(KiokuDB::DoNotSerialize)], lazy => 1, default => "barf" );

    package KiokuDB_Test_Bar;
    use Moose;

    our $VERSION = "0.03";

    with qw(KiokuDB::Role::ID KiokuDB::Role::Upgrade::Data);

    sub kiokudb_object_id { shift->id }

    sub kiokudb_upgrade_data {
        my ( $class, %args ) = @_;

        return $args{entry}->derive( class_version => $VERSION );
    }

    has id => ( is => "ro" );

    has blah => ( is => "rw" );

    package KiokuDB_Test_Gorch;
    use Moose::Role;

    has optional => ( is => "rw" );

    package KiokuDB_Test_Value;
    use Moose;

    with qw(KiokuDB::Role::Intrinsic);

    has name => ( is => "rw" );

    package KiokuDB_Test_Once;
    use Moose;

    our $VERSION = "0.03";

    with qw(KiokuDB::Role::Upgrade::Handlers::Table);

    use constant kiokudb_upgrade_handlers_table => {
        "0.01" => "0.02",
        "0.02" => {
            class_version => "0.03",
        },
    };


    with qw(KiokuDB::Role::Immutable);

    has name => ( is => "rw" );
}

my $obj = KiokuDB_Test_Foo->new( foo => "HALLO" );

$obj->trash if HAVE_MX_STORAGE;
$obj->junk;

my $deep = KiokuDB_Test_Foo->new( foo => "la", bar => KiokuDB_Test_Bar->new( blah => "hai", id => "the_bar" ) );

my $with_anon = KiokuDB_Test_Bar->new( blah => "HALLO", id => "runtime_role" );

KiokuDB_Test_Gorch->meta->apply($with_anon);

$with_anon->optional("very much");

my $anon_parent = KiokuDB_Test_Foo->new( bar => $with_anon );

my $obj_with_value = KiokuDB_Test_Foo->new( foo => KiokuDB_Test_Value->new( name => "fairly" ) );

my $once = KiokuDB_Test_Once->new( name => "blah" );

foreach my $intrinsic ( 1, 0 ) {
    my $foo_entry = KiokuDB::TypeMap::Entry::MOP->new(
        write_upgrades => 1,
        version_table => {
            ""     => "0.01", # equivalent
            "0.01" => sub {
                my ( $self, %args ) = @_;

                return $args{entry}->derive( class_version => "0.02" );
            },
            "0.02" => "0.03",
        },
    );
    my $bar_entry = KiokuDB::TypeMap::Entry::MOP->new( $intrinsic ? ( intrinsic => 1 ) : (), write_upgrades => 1 );

    my $tr = KiokuDB::TypeMap::Resolver->new(
        fallback_entry => KiokuDB::TypeMap::Entry::MOP->new(
            write_upgrades => 1,
        ),
        typemap => KiokuDB::TypeMap->new(
            entries => {
                KiokuDB_Test_Foo => $foo_entry,
                KiokuDB_Test_Bar => $bar_entry,
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

        my ( $buffer, $id ) = $v->collapse( objects => [ $obj ],  );

        my $entries = $buffer->_entries;

        my $entry = $entries->{$id};

        is( scalar(keys %$entries), 1, "one entry" );

        isnt( refaddr($entry->data), refaddr($obj), "refaddr doesn't equal" );
        ok( !blessed($entry->data), "entry data is not blessed" );
        is( reftype($entry->data), reftype($obj), "reftype" );

        my $sl = $l->live_objects->new_scope;

        my $expanded = $l->expand_object($entry);

        isa_ok( $expanded, "KiokuDB_Test_Foo", "expanded object" );
        isnt( refaddr($expanded), refaddr($obj), "refaddr doesn't equal" );
        isnt( refaddr($expanded), refaddr($entry->data), "refaddr doesn't entry data refaddr" );

        ok( !exists($entry->data->{junk}), "DoNotSerialize trait honored" );
        is( $expanded->junk, "barf", "junk attr" );

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

        my ( $buffer, $id ) = $v->collapse( objects => [ $deep ],  );

        my $entries = $buffer->_entries;

        my $entry = $entries->{$id};

        if ( $intrinsic ) {
            is( scalar(keys %$entries), 1, "one entry" );
        } else {
            is( scalar(keys %$entries), 2, "two entries" );
            ok( exists($entries->{the_bar}), "custom ID exists" );
            is( $entries->{the_bar}->class, "KiokuDB_Test_Bar", "right object" );
        }

        isnt( refaddr($entry->data), refaddr($deep), "refaddr doesn't equal" );
        ok( !blessed($entry->data), "entry data is not blessed" );
        is( reftype($entry->data), reftype($deep), "reftype" );

        if ( $intrinsic ) {
            is_deeply(
                $entry->data,
                {%$deep, bar => KiokuDB::Entry->new( class => "KiokuDB_Test_Bar", data => {%$bar}, object => $bar, class_version => $KiokuDB_Test_Bar::VERSION ) },
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

        $l->live_objects->register_entry( $_->id => $_ ) for values %$entries;

        my $expanded = try { $l->expand_object($entry) };

        isa_ok( $expanded, "KiokuDB_Test_Foo", "expanded object" );
        isnt( refaddr($expanded), refaddr($deep), "refaddr doesn't equal" );
        isnt( refaddr($expanded), refaddr($entry->data), "refaddr doesn't entry data refaddr" );
        is_deeply( $expanded, $deep, "is_deeply" );

        is( $expanded->bar->id, "the_bar", "ID attr preserved even if not used" );
    }

    {
        my $s = $v->live_objects->new_scope;

        my ( $buffer, $id ) = $v->collapse( objects => [ $anon_parent ] );

        my $entries = $buffer->_entries;

        my $entry = $entries->{$id};

        if ( $intrinsic ) {
            is( scalar(keys %$entries), 1, "one entry" );
        } else {
            is( scalar(keys %$entries), 2, "two entries" );
            ok( exists($entries->{runtime_role}), "custom ID exists" );
            is( $entries->{runtime_role}->class, "KiokuDB_Test_Bar", "right object" );
        }

        isnt( refaddr($entry->data), refaddr($anon_parent), "refaddr doesn't equal" );
        ok( !blessed($entry->data), "entry data is not blessed" );
        is( reftype($entry->data), reftype($anon_parent), "reftype" );

        if ( $intrinsic ) {
            is_deeply(
                $entry->data,
                {
                    bar => KiokuDB::Entry->new(
                        class => "KiokuDB_Test_Bar",
                        data => {%$with_anon},
                        class_meta => {
                            roles => [qw(KiokuDB_Test_Gorch)]
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

        $l->live_objects->register_entry( $_->id => $_ ) for values %$entries;

        my $expanded = try { $l->expand_object($entry) };

        isa_ok( $expanded, "KiokuDB_Test_Foo", "expanded object" );
        isa_ok( $expanded->bar, "KiokuDB_Test_Bar", "inner obeject" );

        is( $expanded->bar->id, "runtime_role", "ID attr preserved even if not used" );

        does_ok( $expanded->bar, "KiokuDB_Test_Gorch" );
        ok( $expanded->bar->meta->is_anon_class, "anon class" );
    }

    {
        my $s = $v->live_objects->new_scope;

        my ( $buffer, $id ) = $v->collapse( objects => [ $obj_with_value ] );

        my $entries = $buffer->_entries;

        my $entry = $entries->{$id};

        is( scalar(keys %$entries), 1, "one entry" );

        isnt( refaddr($entry->data), refaddr($obj_with_value), "refaddr doesn't equal" );
        ok( !blessed($entry->data), "entry data is not blessed" );
        is( reftype($entry->data), reftype($obj_with_value), "reftype" );

        is_deeply(
            $entry->data,
            {
                foo => KiokuDB::Entry->new(
                    class => "KiokuDB_Test_Value",
                    data => { %{ $obj_with_value->foo } },
                    object => $obj_with_value->foo,
                ),
            },
            "is_deeply"
        );

        my $sl = $l->live_objects->new_scope;

        $l->live_objects->register_entry( $_->id => $_ ) for values %$entries;

        my $expanded = try { $l->expand_object($entry) };

        isa_ok( $expanded, "KiokuDB_Test_Foo", "expanded object" );
        isa_ok( $expanded->foo, "KiokuDB_Test_Value", "inner obeject" );
    }

    {
        my $s = $v->live_objects->new_scope;

        my ( $buffer, $id ) = $v->collapse( objects => [ $once ] );

        my $entries = $buffer->_entries;

        is( scalar(keys %$entries), 1, "one entry" );

        my $entry = $entries->{$id};

        is( ref($entry), "KiokuDB::Entry", "normal entry" );

        isnt( refaddr($entry->data), refaddr($once), "refaddr doesn't equal" );
        ok( !blessed($entry->data), "entry data is not blessed" );
        is( reftype($entry->data), reftype($once), "reftype" );

        is_deeply(
            $entry->data,
            { %$once },
            "is_deeply"
        );

        $v->live_objects->update_entries( map { $_->object => $_ } values %$entries );

        my ( $new_entries, $new_id ) = $v->collapse( objects => [ $once ] );

        is( $new_id, $id, "ID is the same" );

        ok( !exists($new_entries->{$id}), "skipped entry on second insert" );
    }

    {
        my $s = $v->live_objects->new_scope;

        my ( $buffer, $id ) = $v->collapse( objects => [ $deep ],  );

        my $entries = $buffer->_entries;

        my $entry = $entries->{$id};

        my $sl = $l->live_objects->new_scope;

        $l->backend->insert( values %$entries );

        my $expanded = try { $l->expand_object($entry) };

        isa_ok( $expanded, "KiokuDB_Test_Foo", "expanded object" );

        my $bar_addr = refaddr($expanded->bar);

        my $clone = $entry->derive(
            data => {
                %{ $entry->{data} },
                foo => "henry",
            },
        );

        $l->backend->insert($clone);

        is( $expanded->foo, "la", "attr value" );

        $l->refresh_object($expanded);

        is( $expanded->foo, "henry", "attr refreshed" );

        if ( $intrinsic ) {
            isnt( refaddr($expanded->bar), $bar_addr, "bar recreated" );
        } else {
            is( refaddr($expanded->bar), $bar_addr, "bar left in place" );
        }
    }

    {
        my $id = $v->generate_uuid;

        {
            # no class_version
            my $entry = KiokuDB::Entry->new(
                class         => 'KiokuDB_Test_Foo',
                data          => { foo => 'test', },
                id            => $id,
            );

            $l->backend->insert($entry);
        }

        my $s = $l->live_objects->new_scope;

        my $expanded = try {
            $l->get_or_load_object($id)
        } catch {
            fail "error: $_";
        };

        isa_ok( $expanded, "KiokuDB_Test_Foo", "expanded object upgraded" );

        my $upgraded = $l->backend->get($id);

        isa_ok( $upgraded, "KiokuDB::Entry", "upgraded entry written back" );

        is( $upgraded->class_version, '0.02', "correct class version" );
    }

    unless ( $intrinsic ) {
        my $id = $v->generate_uuid;

        {
            # no class_version
            my $entry = KiokuDB::Entry->new(
                class         => 'KiokuDB_Test_Bar',
                data          => { id => $id, blah => "test" },
                id            => $id,
            );

            $l->backend->insert($entry);
        }

        my $s = $l->live_objects->new_scope;

        my $expanded = try {
            $l->get_or_load_object($id)
        } catch {
            fail "error: $_";
        };

        isa_ok( $expanded, "KiokuDB_Test_Bar", "expanded object upgraded" );

        my $upgraded = $l->backend->get($id);

        isa_ok( $upgraded, "KiokuDB::Entry", "upgraded entry written back" );

        is( $upgraded->class_version, '0.03', "correct class version" );
    }

    {
        my $id = $v->generate_uuid;

        {
            # no class_version
            my $entry = KiokuDB::Entry->new(
                class_version => "0.01",
                class         => 'KiokuDB_Test_Once',
                data          => { name => 'test', },
                id            => $id,
            );

            $l->backend->insert($entry);
        }

        my $s = $l->live_objects->new_scope;

        my $expanded = try {
            $l->get_or_load_object($id)
        } catch {
            fail "error: $_";
        };

        isa_ok( $expanded, "KiokuDB_Test_Once", "expanded object upgraded" );

        my $upgraded = $l->backend->get($id);

        isa_ok( $upgraded, "KiokuDB::Entry", "upgraded entry written back" );

        is( $upgraded->class_version, '0.03', "correct class version" );
    }
}


done_testing;
