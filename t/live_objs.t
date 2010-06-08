#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Scalar::Util qw(weaken);

use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::Entry';

{
    package KiokuDB_Test_Foo;
    use Moose;

    has bar => ( is => "rw", weak_ref => 1 );

    has strong_ref => ( is => "rw" );

    package KiokuDB_Test_Bar;
    use Moose;

    has foo => ( is => "rw", weak_ref => 1 );
}

{
    my $l = KiokuDB::LiveObjects->new;

    is_deeply(
        [ $l->live_objects ],
        [ ],
        "no live objects",
    );

    {
        my $s = $l->new_scope;

        my $x = KiokuDB_Test_Foo->new;

        $l->insert( x => $x );

        is_deeply(
            [ $l->live_objects ],
            [ $x ],
            "live object set"
        );
    }

    is_deeply(
        [ $l->live_objects ],
        [ ],
        "live object set is weak"
    );

    {
        my $s = $l->new_scope;

        my %objects = (
            ( map { $_ => KiokuDB_Test_Foo->new } ( 'a' .. 'z' ) ),
            hash  => { foo => "bar" },
            array => [ 1 .. 3 ],
        );

        $l->insert( %objects );

        is_deeply(
            [ sort $l->live_objects ],
            [ sort values %objects ],
            "live object set"
        );

        $l->remove( 'b', $objects{d} );

        is_deeply(
            [ sort $l->live_objects ],
            [ sort grep { $_ != $objects{d} and $_ != $objects{b} } values %objects ],
            "remove",
        );

        is_deeply( [ $l->ids_to_objects(qw(f array)) ], [ @objects{qw(f array)} ], "id to object" );

        throws_ok { $l->insert( g => $objects{f} ) } qr/already registered/, "double reg under diff ID is an error";

        throws_ok { $l->insert( foo => "bar" ) } qr/not a ref/, "can't register non ref";

        undef $s;

        my @objects = ( $objects{n}, $objects{hash} );

        %objects = ();

        is_deeply(
            [ sort $l->live_objects ],
            [ sort @objects ],
            "live object set reduced"
        );
    }

    is_deeply(
        [ $l->live_objects ],
        [ ],
        "live object set is now empty"
    );
}

{
    my $l = KiokuDB::LiveObjects->new;

    is( $l->objects_to_ids(KiokuDB_Test_Foo->new), undef, "random object has undef ID" );
    is_deeply( [ $l->objects_to_ids(KiokuDB_Test_Foo->new, KiokuDB_Test_Foo->new) ], [ undef, undef ], "random objects have undef IDs" );
}

{
    my $l = KiokuDB::LiveObjects->new;

    {
        my $entry = KiokuDB::Entry->new( id => "oink" );
        $l->insert_entries($entry);

        is_deeply( [ $l->loaded_ids ], ["oink"], "loaded IDs" );

        is_deeply( [ $l->ids_to_entries("oink") ], [ $entry ], "ids_to_entries" );
    }

    is_deeply( [ $l->loaded_ids ], [], "loaded IDs" );
}

{
    my $l = KiokuDB::LiveObjects->new;

    my $s = $l->new_scope;

    my $entry = KiokuDB::Entry->new( id => "blah" );
    my $blah = KiokuDB_Test_Foo->new;
    $l->insert( $entry => $blah );

    is_deeply( [ $l->objects_to_entries($blah) ], [ $entry ], "objects to entries" );

    is_deeply( [ $l->ids_to_entries("blah") ], [ $entry ], "ids to entries" );
}

{
    my $l = KiokuDB::LiveObjects->new;

    my $foo;

    {
        my $s = $l->new_scope;

        my $inner_foo = $foo = KiokuDB_Test_Foo->new;
        weaken($foo);
        my $bar = KiokuDB_Test_Bar->new;

        $foo->bar($bar);
        $bar->foo($foo);

        $l->insert( foo => $foo );

        is_deeply(
            [ $l->live_objects ],
            [ $foo ],
            "live object set"
        );
    }

    is_deeply(
        [ $l->live_objects ],
        [ ],
        "live object set is now empty"
    );

    is( $foo, undef, "foo undefined" );

    {
        my $s = $l->new_scope;

        is( $s->parent, undef, "no parent scope" );

        {
            my $inner_foo = $foo = KiokuDB_Test_Foo->new;
            weaken($foo);
            my $bar = KiokuDB_Test_Bar->new;

            $foo->bar($bar);
            $bar->foo($foo);

            $l->insert( foo => $foo );

            is( $l->current_scope, $s, "current scope" );

            is_deeply(
                [ $l->live_objects ],
                [ $foo ],
                "live object set"
            );

            {
                my $child_s = $l->new_scope;

                is( $child_s->parent, $s, "new scope has parent" );

                is( $l->current_scope, $child_s, "current scope" );

                $l->insert( blah => KiokuDB_Test_Foo->new );

                is( scalar($l->live_objects), 2, "two live objects" );

                isa_ok( $l->id_to_object("blah"), "KiokuDB_Test_Foo" );

                is_deeply(
                    [ sort $l->live_objects ],
                    [ sort $foo, $l->id_to_object("blah") ],
                    "live object set has new anon member"
                );
            }

            is( $l->current_scope, $s, "current scope" );

            is_deeply(
                [ $l->live_objects ],
                [ $foo ],
                "live object set"
            );
        }

        is_deeply(
            [ $l->live_objects ],
            [ $foo ],
            "live object set"
        );
    }

    is( $l->current_scope, undef, "scope cleared" );

    is( $foo, undef, "foo undefined" );

    is_deeply(
        [ $l->live_objects ],
        [ ],
        "live object set is now empty"
    );
}

{
    my $l = KiokuDB::LiveObjects->new;

    {
        my $s = $l->new_scope;

        my $foo = KiokuDB_Test_Foo->new;

        $l->insert( foo => $foo );

        is_deeply( [ $l->live_objects ], [ $foo ], "live object set" );

        is_deeply( [ $s->objects ], [ $foo ], "scope objects" );

        $s->detach;

        is( $l->current_scope, undef, "scope detached:" );

        is_deeply( [ $l->live_objects ], [ $foo ], "live object set" );

        is_deeply( [ $s->objects ], [ $foo ], "scope objects" );

        my $s2 = $l->new_scope;

        my $bar = KiokuDB_Test_Bar->new;

        $l->insert( bar => $bar );

        is_deeply( [ sort $l->live_objects ], [ sort $foo, $bar ], "live object set" );

        is_deeply( [ $s->objects ], [ $foo ], "scope objects" );

        is_deeply( [ $s2->objects ], [ $bar ], "second scope objects" );

        $s->remove;
        undef $foo;

        is_deeply( [ $l->live_objects ], [ $bar ], "disjoint scope death" );

        is_deeply( [ $s2->objects ], [ $bar ], "second scope objects" );
    }

    is_deeply(
        [ $l->live_objects ],
        [ ],
        "live object set is now empty"
    );
}

{
    my $leak_tracker_called;

    my $l = KiokuDB::LiveObjects->new(
        clear_leaks => 1,
        leak_tracker => sub {
            $leak_tracker_called++;
            $_->strong_ref(undef) for @_;
        }
    );

    my $foo = KiokuDB_Test_Foo->new;
    my $bar = KiokuDB_Test_Foo->new;

    $foo->strong_ref($bar);
    $bar->strong_ref($foo);

    weaken $foo;
    weaken $bar;

    ok( defined($foo), "circular refs keep structure alive" );

    {
        my $s = $l->new_scope;

        {
            my $s2 = $l->new_scope;

            $l->insert( foo => $foo );

            is_deeply( [ $l->live_objects ], [ $foo ], "live object set" );

            is_deeply( [ $s2->objects ], [ $foo ], "scope objects" );
        }

        is_deeply( [ $s->objects ], [ ], "no scope objects" );

        my @live = $l->live_objects;
        is( scalar(@live), 1, "circular ref still live" );
    }

    is( $l->current_scope, undef, "no current scope" );

    is_deeply(
        [ $l->live_objects ],
        [ ],
        "live object set is now empty"
    );

    ok( $leak_tracker_called, "leak tracker called" );

    is( $foo, undef, "structure has been manually cleared" );
}

done_testing;
