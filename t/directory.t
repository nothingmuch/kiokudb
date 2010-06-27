#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Try::Tiny;

BEGIN { eval 'use Test::Memory::Cycle; 1' or eval 'sub memory_cycle_ok { SKIP: { skip "Test::Memory::Cycle missing", 1 }}' }

use Scalar::Util qw(blessed weaken isweak refaddr);

BEGIN { $KiokuDB::SERIAL_IDS = 1 }

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::Hash';

sub no_live_objects {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    our $dir;

    is_deeply(
        [ $dir->live_objects->live_objects ],
        [],
        "live object set is empty",
    );

    is_deeply(
        [ $dir->live_objects->live_entries ],
        [],
        "live entry set is empty",
    );

    if ( my @entries = $dir->live_objects->live_entries ) {
        $dir->live_objects->clear;
        diag Devel::FindRef::track($entries[0], 100);
        $entries[0]{__destroyed} = Scope::Guard->new(sub { Carp::cluck("finally destroyed") });
        diag($dir->live_objects->dump);
    }
}

{
    package KiokuDB_Test_Foo;
    use Moose;

    our $VERSION = "0.02";

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

foreach my $keep_entries ( 1, 0 ) {
our $dir = KiokuDB->new(
    live_objects => {
        keep_entries => $keep_entries,
    },
    check_class_versions => 1,
    class_version_table => {
        KiokuDB_Test_Foo => {
            "0.01" => {
                class_version => "0.02",
                data          => { foo => "upgraded" },
            },
        },
    },
    backend => KiokuDB::Backend::Hash->new,
    #backend => KiokuDB::Backend::JSPON->new(
    #    dir    => temp_root,
    #    pretty => 1,
    #    lock   => 0,
    #),
);


my $l = $dir->live_objects;

# Pixie ain't got nuthin on us
my $id;

{
    my $s = $dir->new_scope;

    my $x = KiokuDB_Test_Foo->new(
        foo => "dancing",
        bar => KiokuDB_Test_Foo->new(
            foo => "oh",
        ),
    );

    memory_cycle_ok($x, "no cycles in proto obj" );

    $x->bar->parent($x);

    memory_cycle_ok($x, "cycle is weak");

    memory_cycle_ok($s, "no cycles in scope");
    memory_cycle_ok($l, "no cycles in live objects");

    $id = $dir->store($x);

    memory_cycle_ok($s, "no cycles in scope");
    memory_cycle_ok($l, "no cycles in live objects");

    if ( $keep_entries ) {
        my $entry = $l->object_to_entry($x);

        ok( $entry, "got an entry for $id" );

        is( try { $entry->id }, $id, "with the right entry" );

        is( try { $entry->object }, $x, "and the right object" );
    } else {
        is( $l->object_to_entry($x), undef, "no entry" );
    }


    memory_cycle_ok($x, "store did not introduce cycles");

    is_deeply(
        [ sort $l->live_objects ],
        [ sort $x, $x->bar ],
        "live object set"
    );
};

no_live_objects;

memory_cycle_ok($l, "no cycles in live objects");

my $weak;

{
    my $s = $dir->new_scope;

    my $obj = $dir->lookup($id);

    weaken($weak = $obj);

    memory_cycle_ok($obj, "no cycles in object");

    memory_cycle_ok($s, "no cycles in scope");
    memory_cycle_ok($l, "no cycles in live objects");

    is( $obj->foo, "dancing", "simple attr" );
    isa_ok( $obj->bar, "KiokuDB_Test_Foo", "object attr" );
    is( $obj->bar->foo, "oh", "simple attr of sub object" );
    isa_ok( $obj->bar->parent, "KiokuDB_Test_Foo", "object attr of sub object" );
    is( $obj->bar->parent, $obj, "circular ref" );
}

is( $weak, undef, "weak ref to object died" );

no_live_objects;

memory_cycle_ok($l, "no cycles in live objects");

{
    my $s = $dir->new_scope;

    my $x = KiokuDB_Test_Foo->new(
        foo => "oink oink",
        bar => my $y = KiokuDB_Test_Foo->new(
            foo => "yay",
        ),
    );

    my @ids = $dir->store($x, $y);

    is( scalar(@ids), 2, "got two ids" );

    $s->clear;

    undef $x;

    is( $l->id_to_object($ids[0]), undef, "first object is dead" );
    is( $l->id_to_object($ids[1]), $y, "second is still alive" );

    {
        my $s = $dir->new_scope;
        my @objects = map { $dir->lookup($_) } @ids;

        isa_ok( $objects[0], "KiokuDB_Test_Foo" );
        is( $objects[0]->foo, "oink oink", "object retrieved" );
        is( $objects[1], $y, "object is already live" );
        is( $objects[0]->bar, $y, "link recreated" );
    }
}

no_live_objects;

{
    my $s = $dir->new_scope;

    my @ids = do{
        my $s = $dir->new_scope;

        my $shared = KiokuDB_Test_Foo->new( foo => "shared" );

        my $first  = KiokuDB_Test_Foo->new( foo => "first",  bar => $shared );
        my $second = KiokuDB_Test_Foo->new( foo => "second", bar => $shared );

        $dir->store( $first, $second );
    };

    no_live_objects;

    my $first = $dir->lookup($ids[0]);

    isa_ok( $first, "KiokuDB_Test_Foo" );
    is( $first->foo, "first", "normal attr" );
    isa_ok( $first->bar, "KiokuDB_Test_Foo", "shared object" );
    is( $first->bar->foo, "shared", "normal attr of shared" );

    my $second = $dir->lookup($ids[1]);

    isa_ok( $second, "KiokuDB_Test_Foo" );
    is( $second->foo, "second", "normal attr" );

    is( $second->bar, $first->bar, "shared object" );
}

no_live_objects;

{
    my $s = $dir->new_scope;

    my @ids = do{
        my $s = $dir->new_scope;

        my $shared = { foo => "shared", object => KiokuDB_Test_Foo->new( foo => "shared child" ) };

        $shared->{object}->parent($shared);

        my $first  = KiokuDB_Test_Foo->new( foo => "first",  bar => $shared );
        my $second = KiokuDB_Test_Foo->new( foo => "second", bar => $shared );

        $dir->store( $first, $second );
    };

    no_live_objects;

    my $first = $dir->lookup($ids[0]);

    isa_ok( $first, "KiokuDB_Test_Foo" );
    is( $first->foo, "first", "normal attr" );

    is( ref($first->bar), "HASH", "shared hash" );
    is( $first->bar->{foo}, "shared", "hash data" );

    isa_ok( $first->bar->{object}, "KiokuDB_Test_Foo", "indirect shared child" );

    my $second = $dir->lookup($ids[1]);

    isa_ok( $second, "KiokuDB_Test_Foo" );
    is( $second->foo, "second", "normal attr" );

    is( $second->bar, $first->bar, "shared value" );
}

no_live_objects;

{
    my $s = $dir->new_scope;

    my $id = do{
        my $s = $dir->new_scope;

        my $shared = { foo => "hippies" };

        weaken($shared->{self} = $shared);

        $dir->store( KiokuDB_Test_Foo->new( foo => "blimey", bar => $shared ) );
    };

    no_live_objects;

    my $obj = $dir->lookup($id);

    isa_ok( $obj, "KiokuDB_Test_Foo" );
    is( $obj->foo, "blimey", "normal attr" );

    is( ref($obj->bar), "HASH", "shared hash" );
    is( $obj->bar->{foo}, "hippies", "hash data" );
    is( $obj->bar->{self}, $obj->bar, "circular ref" );

    ok( isweak($obj->bar->{self}), "weak ref" );
}

no_live_objects;


{
    my $s = $dir->new_scope;

    my $id = $dir->insert( KiokuDB_Test_Foo->new( foo => "henry" ) );
    ok( $id, "insert returns ID for new object" );

    $s->clear;

    no_live_objects;

    my $obj = $dir->lookup($id);

    is( $obj->foo, "henry", "stored by insert" );

    throws_ok {
        $dir->insert($obj)
    } qr/already in database/i, "insertion of present object is an error";
}

no_live_objects;


{
    my $id = do {
        my $s = $dir->new_scope;
        $dir->store( KiokuDB_Test_Foo->new( foo => "blimey" ) );
    };

    no_live_objects;

    {
        my $s = $dir->new_scope;

        my $obj = $dir->lookup($id);

        isa_ok( $obj, "KiokuDB_Test_Foo" );
        is( $obj->foo, "blimey", "normal attr" );

        $obj->foo("fancy");

        is( $obj->foo, "fancy", "attr changed" );
    }

    no_live_objects;

    {
        my $s = $dir->new_scope;

        my $obj = $dir->lookup($id);

        isa_ok( $obj, "KiokuDB_Test_Foo" );
        is( $obj->foo, "blimey", "change not saved" );

        $obj->foo("pancy");

        is( $obj->foo, "pancy", "attr changed" );

        throws_ok {
            $dir->insert($obj)
        } qr/already in database/i, "insertion of present object is an error";
    }

    no_live_objects;

    {
        my $s = $dir->new_scope;

        my $obj = $dir->lookup($id);

        isa_ok( $obj, "KiokuDB_Test_Foo" );
        is( $obj->foo, "blimey", "change not saved" );

        $obj->foo("shmancy");

        is( $obj->foo, "shmancy", "attr changed" );

        is( $dir->store($obj), $id, "ID" );
    }

    no_live_objects;

    {
        my $s = $dir->new_scope;

        my $obj = $dir->lookup($id);

        isa_ok( $obj, "KiokuDB_Test_Foo" );
        is( $obj->foo, "shmancy", "store saved change" );

        is( $obj->bar, undef, "no 'bar' attr" );

        $obj->bar( KiokuDB_Test_Foo->new( foo => "child" ) );

        is( $dir->store($obj), $id, "ID" );
    }

    no_live_objects;

    {
        my $s = $dir->new_scope;

        my $child;

        {
            my $s = $dir->new_scope;

            my $obj = $dir->lookup($id);

            isa_ok( $obj, "KiokuDB_Test_Foo" );

            isa_ok( $obj->bar, "KiokuDB_Test_Foo" );

            is( $obj->bar->foo, "child", "child object's attr" );

            $child = $obj->bar;
        }

        is_deeply(
            [ $l->live_objects ],
            [ $child ],
            "only child in live object set",
        );


        {
            my $s = $dir->new_scope;

            my $obj = $dir->lookup($id);

            isa_ok( $obj, "KiokuDB_Test_Foo" );

            isa_ok( $obj->bar, "KiokuDB_Test_Foo" );

            is( $obj->bar->foo, "child", "child object's attr" );

            is( refaddr($obj->bar), refaddr($child), "same refaddr as live object" );

            is_deeply(
                [ sort $l->live_objects ],
                [ sort $child, $obj ],
                "two objects in live object set",
            );

            $obj->bar( KiokuDB_Test_Foo->new( foo => "third" ) );

            $dir->store( $obj->bar );
        }

        {
            my $s = $dir->new_scope;

            my $obj = $dir->lookup($id);

            isa_ok( $obj, "KiokuDB_Test_Foo" );

            isa_ok( $obj->bar, "KiokuDB_Test_Foo" );

            is( $obj->bar->foo, "child", "child object's attr unchanged" );

            is( refaddr($obj->bar), refaddr($child), "same refaddr as live object" );

            $obj->bar( KiokuDB_Test_Foo->new( foo => "third" ) );

            $dir->store( $obj );
        }

        {
            my $s = $dir->new_scope;

            my $obj = $dir->lookup($id);

            isa_ok( $obj, "KiokuDB_Test_Foo" );

            isa_ok( $obj->bar, "KiokuDB_Test_Foo" );

            isnt( refaddr($obj->bar), refaddr($child), "same refaddr as live object" );

            is( $obj->bar->foo, "third", "child inserted due to parent's update" );

            $dir->store( $obj );
        }
    }
}

no_live_objects;


{
    my $id = do {
        my $s = $dir->new_scope;
        $dir->insert( KiokuDB_Test_Foo->new( foo => "hippies" ) );
    };

    ok( $id, "insert returns ID for new object" );

    no_live_objects;

    {
        my $s = $dir->new_scope;

        my $obj = $dir->lookup($id);

        is( $obj->foo, "hippies", "stored by insert" );

        $obj->foo("blah");
    }

    no_live_objects;

    {
        my $s = $dir->new_scope;

        my $obj = $dir->lookup($id);

        is( $obj->foo, "hippies", "not updated" );

        $obj->foo("goddamn");

        my $entry;
        if ( $keep_entries ) {
            $entry = $l->object_to_entry($obj);

            ok( $entry, "got an entry" );

            is( $entry->id, $id, "right id" );
        } else {
            $entry = $l->object_to_entry($obj);
            is( $entry, undef, "no entry" ) or diag(Devel::FindRef::track($entry, 100));
        }

        $dir->update($obj);

        if ( $keep_entries ) {
            my $update_entry = $l->object_to_entry($obj);

            ok( $update_entry, "got an update entry" );

            is( $update_entry->id, $id, "right id" );

            is( $update_entry->prev, $entry, "prev entry" );
        } else {
            is( $l->object_to_entry($obj), undef, "no entry" );
        }
    }

    no_live_objects;

    my $child = KiokuDB_Test_Foo->new( foo => "meddling kids" );

    {
        my $s = $dir->new_scope;

        my $obj = $dir->lookup($id);

        is( $obj->foo, "goddamn", "updated" );

        $obj->bar( $child );

        $@ = "";
        try {
            $dir->update($obj);
            fail("expected error");
        } catch {
            is_deeply( $_, KiokuDB::Error::UnknownObjects->new( objects => [ $child ] ), "update with a partial object" );
        };

        $dir->insert($child);

        ok( $l->object_to_id($child), "child has ID now" );

        ok( $l->object_in_storage($child), "its in storage" );

        if ( $keep_entries ) {
            isa_ok( $l->object_to_entry($child), "KiokuDB::Entry" );
        } else {
            is( $l->object_to_entry($child), undef, "KiokuDB::Entry" );
        }

        lives_ok { $dir->update($obj) } "no error this time";
    }

    {
        my $s = $dir->new_scope;

        my $obj = $dir->lookup($id);

        is( $obj->bar, $child, "updated" );

        undef $child;

        $obj->bar->foo("OH HAI");

        $dir->update( $obj );
    }

    no_live_objects;

    {
        my $s = $dir->new_scope;

        my $obj = $dir->lookup($id);

        is( $obj->bar->foo, "meddling kids", "update is shallow" );

        $obj->bar->foo("three");

        $dir->update( $obj->bar );
    }

    no_live_objects;

    {
        my $s = $dir->new_scope;

        my $obj = $dir->lookup($id);

        is( $obj->bar->foo, "three", "updated" );
    }
}

no_live_objects;

{
    my $s = $dir->new_scope;

    my $id = do {
        my $s = $dir->new_scope;

        $dir->store(
            KiokuDB_Test_Foo->new(
                foo => "dancing",
                bar => KiokuDB_Test_Foo->new(
                    foo => "oh",
                ),
            ),
        );
    };

    no_live_objects;

    {
        my $s = $dir->new_scope;
        isa_ok( $dir->lookup($id), "KiokuDB_Test_Foo" );
    }

    no_live_objects;

    $dir->delete($id);

    no_live_objects;

    is( $dir->lookup($id), undef, "deleted" );
};

no_live_objects;

{
    my $s = $dir->new_scope;

     my $id = $dir->store(
        my $foo = KiokuDB_Test_Foo->new(
            foo => "dancing",
            bar => my $bar = KiokuDB_Test_Foo->new(
                foo => "oh",
            ),
        ),
    );

    if ( $keep_entries ) {
        my @entries = $l->objects_to_entries($foo, $bar);

        is( scalar(@entries), 2, "two entries" );
        is( $entries[0]->object, $foo, "entry object" );
        is( $entries[1]->object, $bar, "entry object" );

        $dir->delete($foo, $bar);

        is( $l->object_to_entry($foo), undef, "no entry object" );
        is( $l->object_to_entry($bar), undef, "no entry object" );
    } else {
        is_deeply( [ $l->live_entries ], [ ], "no live entries" );
    }
};

no_live_objects;

{
    my $s = $dir->new_scope;

    my $id = $dir->store(
        blah => my $foo = KiokuDB_Test_Foo->new( foo => "dancing" ),
    );

    is( $id, "blah", "custom id" );

    is( $l->object_to_id($foo), "blah", "object to id" );

    if ( $keep_entries ) {
        isa_ok( my $entry = $l->object_to_entry($foo), "KiokuDB::Entry" );
        ok( $entry->root, "root object" );
    } else {
        is( $l->object_to_entry($foo), undef, "no entry" );
    }

    ok( $dir->is_root($foo), "object is in root set" );
};

no_live_objects;

{
    my $s = $dir->new_scope;

    my $id = $dir->insert_nonroot(
        nonroot_object => my $foo = KiokuDB_Test_Foo->new( foo => "lala" ),
    );

    is( $id, "nonroot_object", "custom id" );

    is( $l->object_to_id($foo), "nonroot_object", "object to id" );

    if ( $keep_entries ) {
        isa_ok( my $entry = $l->object_to_entry($foo), "KiokuDB::Entry" );
        ok( !$entry->root, "not root" );
    } else {
        is( $l->object_to_entry($foo), undef, "no entry" );
    }

    ok( !$dir->is_root($foo), "object is not in root set" );
};

no_live_objects;

{
    {
        my $s = $dir->new_scope;

        my $id = $dir->insert( KiokuDB_Test_Foo->new( foo => "blah blah" ) );

        my ( $entry ) = $dir->backend->get($id);

        my $old_entry = $entry->clone(
            class_version => "0.01",
            id            => "old_object",
        );

        $dir->backend->insert($old_entry);
    }

    {
        my $s = $dir->new_scope;

        my $obj = $dir->lookup("old_object");

        isa_ok( $obj, "KiokuDB_Test_Foo" );

        is( $obj->foo, "upgraded", "field upgraded" );
    }
};

no_live_objects;

}

done_testing;
