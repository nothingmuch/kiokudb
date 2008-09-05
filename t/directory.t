#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Memory::Cycle;

use Scalar::Util qw(blessed weaken isweak refaddr);

BEGIN { $KiokuDB::SERIAL_IDS = 1 }

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::Hash';

my $dir = KiokuDB->new(
    backend => KiokuDB::Backend::Hash->new,
    #backend => KiokuDB::Backend::JSPON->new(
    #    dir    => temp_root,
    #    pretty => 1,
    #    lock   => 0,
    #),
);

sub no_live_objects {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is_deeply(
        [ $dir->live_objects->live_objects ],
        [],
        "live object set is empty",
    );
}

{
    package Foo;
    use Moose;

    has foo => (
        isa => "Str",
        is  => "rw",
    );

    has bar => (
        is => "rw",
    );

    has parent => (
        is  => "rw",
        weak_ref => 1,
    );

    __PACKAGE__->meta->make_immutable;
}

# Pixie ain't got nuthin on us
my $id;

{
    my $x = Foo->new(
        foo => "dancing",
        bar => Foo->new(
            foo => "oh",
        ),
    );

    memory_cycle_ok($x, "no cycles in proto obj" );

    $x->bar->parent($x);

    memory_cycle_ok($x, "cycle is weak");

    $id = $dir->store($x);

    my $entry = $dir->live_objects->objects_to_entries($x);

    ok( $entry, "got an entry for $id" );

    is( $entry->id, $id, "with the right entry" );

    is( $entry->object, $x, "and the right object" );

    memory_cycle_ok($x, "store did not introduce cycles");

    is_deeply(
        [ sort $dir->live_objects->live_objects ],
        [ sort $x, $x->bar ],
        "live object set"
    );
};

no_live_objects;

{
    my $obj = $dir->lookup($id);

    is( $obj->foo, "dancing", "simple attr" );
    isa_ok( $obj->bar, "Foo", "object attr" );
    is( $obj->bar->foo, "oh", "simple attr of sub object" );
    isa_ok( $obj->bar->parent, "Foo", "object attr of sub object" );
    is( $obj->bar->parent, $obj, "circular ref" );
}

no_live_objects;

{
    my $x = Foo->new(
        foo => "oink oink",
        bar => my $y = Foo->new(
            foo => "yay",
        ),
    );

    my @ids = $dir->store($x, $y);

    is( scalar(@ids), 2, "got two ids" );

    undef $x;

    is( $dir->live_objects->id_to_object($ids[0]), undef, "first object is dead" );
    is( $dir->live_objects->id_to_object($ids[1]), $y, "second is still alive" );

    my @objects = map { $dir->lookup($_) } @ids;

    isa_ok( $objects[0], "Foo" );
    is( $objects[0]->foo, "oink oink", "object retrieved" );
    is( $objects[1], $y, "object is already live" );
    is( $objects[0]->bar, $y, "link recreated" );
}

no_live_objects;

{
    my @ids = do{
        my $shared = Foo->new( foo => "shared" );

        my $first  = Foo->new( foo => "first",  bar => $shared );
        my $second = Foo->new( foo => "second", bar => $shared );

        $dir->store( $first, $second );
    };

    no_live_objects;

    my $first = $dir->lookup($ids[0]);

    isa_ok( $first, "Foo" );
    is( $first->foo, "first", "normal attr" );
    isa_ok( $first->bar, "Foo", "shared object" );
    is( $first->bar->foo, "shared", "normal attr of shared" );

    my $second = $dir->lookup($ids[1]);

    isa_ok( $second, "Foo" );
    is( $second->foo, "second", "normal attr" );

    is( $second->bar, $first->bar, "shared object" );
}

no_live_objects;

{
    my @ids = do{
        my $shared = { foo => "shared", object => Foo->new( foo => "shared child" ) };

        $shared->{object}->parent($shared);

        my $first  = Foo->new( foo => "first",  bar => $shared );
        my $second = Foo->new( foo => "second", bar => $shared );

        $dir->store( $first, $second );
    };

    no_live_objects;

    my $first = $dir->lookup($ids[0]);

    isa_ok( $first, "Foo" );
    is( $first->foo, "first", "normal attr" );

    is( ref($first->bar), "HASH", "shared hash" );
    is( $first->bar->{foo}, "shared", "hash data" );

    isa_ok( $first->bar->{object}, "Foo", "indirect shared child" );

    my $second = $dir->lookup($ids[1]);

    isa_ok( $second, "Foo" );
    is( $second->foo, "second", "normal attr" );

    is( $second->bar, $first->bar, "shared value" );
}

no_live_objects;

{
    my $id = do{
        my $shared = { foo => "hippies" };

        weaken($shared->{self} = $shared);

        $dir->store( Foo->new( foo => "blimey", bar => $shared ) );
    };

    no_live_objects;

    my $obj = $dir->lookup($id);

    isa_ok( $obj, "Foo" );
    is( $obj->foo, "blimey", "normal attr" );

    is( ref($obj->bar), "HASH", "shared hash" );
    is( $obj->bar->{foo}, "hippies", "hash data" );
    is( $obj->bar->{self}, $obj->bar, "circular ref" );

    {
        local $TODO = "weaken is not yet supported in expander";
        ok( isweak($obj->bar->{self}), "weak ref" );

        weaken($obj->bar->{self}); # to make no_live_objects pass
    }
}

no_live_objects;


{
    my $id = $dir->insert( Foo->new( foo => "henry" ) );
    ok( $id, "insert returns ID for new object" );

    no_live_objects;

    my $obj = $dir->lookup($id);

    is( $obj->foo, "henry", "stored by insert" );

    is( $dir->insert($obj), undef, "insert returns undef" );
}

no_live_objects;


{
    my $id = $dir->store( Foo->new( foo => "blimey" ) );

    no_live_objects;

    {
        my $obj = $dir->lookup($id);

        isa_ok( $obj, "Foo" );
        is( $obj->foo, "blimey", "normal attr" );

        $obj->foo("fancy");

        is( $obj->foo, "fancy", "attr changed" );
    }

    no_live_objects;

    {
        my $obj = $dir->lookup($id);

        isa_ok( $obj, "Foo" );
        is( $obj->foo, "blimey", "change not saved" );

        $obj->foo("pancy");

        is( $obj->foo, "pancy", "attr changed" );

        is( $dir->insert($obj), undef, "insert returns undef for live object" );
    }

    no_live_objects;

    {
        my $obj = $dir->lookup($id);

        isa_ok( $obj, "Foo" );
        is( $obj->foo, "blimey", "change not saved" );

        $obj->foo("shmancy");

        is( $obj->foo, "shmancy", "attr changed" );

        is( $dir->store($obj), $id, "ID" );
    }

    no_live_objects;

    {
        my $obj = $dir->lookup($id);

        isa_ok( $obj, "Foo" );
        is( $obj->foo, "shmancy", "store saved change" );

        is( $obj->bar, undef, "no 'bar' attr" );

        $obj->bar( Foo->new( foo => "child" ) );

        is( $dir->store($obj), $id, "ID" );
    }

    no_live_objects;

    {
        my $child;

        {
            my $obj = $dir->lookup($id);

            isa_ok( $obj, "Foo" );

            isa_ok( $obj->bar, "Foo" );

            is( $obj->bar->foo, "child", "child object's attr" );

            $child = $obj->bar;
        }

        is_deeply(
            [ $dir->live_objects->live_objects ],
            [ $child ],
            "only child in live object set",
        );


        {
            my $obj = $dir->lookup($id);

            isa_ok( $obj, "Foo" );

            isa_ok( $obj->bar, "Foo" );

            is( $obj->bar->foo, "child", "child object's attr" );

            is( refaddr($obj->bar), refaddr($child), "same refaddr as live object" );

            is_deeply(
                [ sort $dir->live_objects->live_objects ],
                [ sort $child, $obj ],
                "two objects in live object set",
            );

            $obj->bar( Foo->new( foo => "third" ) );

            $dir->store( $obj->bar );
        }

        {
            my $obj = $dir->lookup($id);

            isa_ok( $obj, "Foo" );

            isa_ok( $obj->bar, "Foo" );

            is( $obj->bar->foo, "child", "child object's attr unchanged" );

            is( refaddr($obj->bar), refaddr($child), "same refaddr as live object" );

            $obj->bar( Foo->new( foo => "third" ) );

            $dir->store( $obj );
        }

        {
            my $obj = $dir->lookup($id);

            isa_ok( $obj, "Foo" );

            isa_ok( $obj->bar, "Foo" );

            isnt( refaddr($obj->bar), refaddr($child), "same refaddr as live object" );

            is( $obj->bar->foo, "third", "child inserted due to parent's update" );

            $dir->store( $obj );
        }
    }
}

no_live_objects;


{
    my $id = $dir->insert( Foo->new( foo => "hippies" ) );

    ok( $id, "insert returns ID for new object" );

    no_live_objects;

    {
        my $obj = $dir->lookup($id);

        is( $obj->foo, "hippies", "stored by insert" );

        $obj->foo("blah");
    }

    no_live_objects;

    {
        my $obj = $dir->lookup($id);

        is( $obj->foo, "hippies", "not updated" );

        $obj->foo("goddamn");

        my $entry = $dir->live_objects->objects_to_entries($obj);

        ok( $entry, "got an entry" );

        is( $entry->id, $id, "right id" );

        $dir->update($obj);

        my $update_entry = $dir->live_objects->objects_to_entries($obj);

        ok( $update_entry, "got an update entry" );

        is( $update_entry->id, $id, "right id" );

        is( $update_entry->prev, $entry, "prev entry" );
    }

    no_live_objects;

    my $child = Foo->new( foo => "meddling kids" );

    {
        my $obj = $dir->lookup($id);

        is( $obj->foo, "goddamn", "updated" );

        $obj->bar( $child );

        eval { $dir->update($obj) };

        is_deeply( $@, { unknown => $child }, "update with a partial object" );

        $dir->insert($child);

        eval { $dir->update($obj) };

        ok( !$@, "no error this time" );
    }

    {
        my $obj = $dir->lookup($id);

        is( $obj->bar, $child, "updated" );

        undef $child;

        $obj->bar->foo("OH HAI");

        $dir->update( $obj );
    }

    no_live_objects;

    {
        my $obj = $dir->lookup($id);

        is( $obj->bar->foo, "meddling kids", "update is shallow" );

        $obj->bar->foo("three");

        $dir->update( $obj->bar );
    }

    no_live_objects;

    {
        my $obj = $dir->lookup($id);

        is( $obj->bar->foo, "three", "updated" );
    }
}

no_live_objects;

{
     my $id = $dir->store(
        Foo->new(
            foo => "dancing",
            bar => Foo->new(
                foo => "oh",
            ),
        ),
    );

    no_live_objects;

    isa_ok( $dir->lookup($id), "Foo" );

    no_live_objects;

    $dir->delete($id);

    no_live_objects;

    is( $dir->lookup($id), undef, "deleted" );
};

no_live_objects;

{
     my $id = $dir->store(
        my $foo = Foo->new(
            foo => "dancing",
            bar => Foo->new(
                foo => "oh",
            ),
        ),
    );

    my $entry = $dir->live_objects->objects_to_entries($foo);

    is( $entry->object, $foo, "entry object" );

    $dir->delete($foo);

    my $del_entry = $dir->live_objects->objects_to_entries($foo);

    ok( $del_entry->deleted, "entry updated in live objects" );

    is( $del_entry->prev, $entry, "prev entry" )
};

no_live_objects;
