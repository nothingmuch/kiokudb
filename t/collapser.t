#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use Scalar::Util qw(weaken isweak);

use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::Resolver';
use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::TypeMap';
use ok 'KiokuDB::TypeMap::Resolver';

{
    package Foo;
    use Moose;

    # check reserved field clashes
    has id => ( is => "rw" );

    has bar => ( is => "rw" );

    has zot => ( is => "rw" );

    __PACKAGE__->meta->make_immutable;

    package Bar;
    use Moose;

    has id => ( is => "rw", isa => "Int" );

    has blah => ( is  => "rw" );
}

{
    my $v = KiokuDB::Collapser->new(
        resolver => KiokuDB::Resolver->new(
            live_objects => KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $foo = Foo->new(
        id  => "oink",
        zot => "zot",
        bar => Bar->new(
            id => 3,
            blah => {
                oink => 3
            },
        ),
    );

    {
        my @partial = eval { $v->collapse_known_objects($foo) };
        is_deeply( $@, { unknown => $foo }, "error" );
        is( scalar(grep { defined } @partial), 0, "no entries for known obj collapse" );
    }

    {
        my $obj = Foo->new( bar => $foo->bar );

        $v->resolver->object_to_id($obj);

        my @partial = eval { $v->collapse_known_objects($obj) };
        is_deeply( $@, { unknown => $foo->bar }, "error" );
        is( scalar(grep { defined } @partial), 0, "no entries for known obj collapse" );
    }

    $v->resolver->object_to_id($foo->bar);

    {
        my @partial = eval { $v->collapse_known_objects($foo) };
        is_deeply( $@, { unknown => $foo }, "error" );
        is( scalar(grep { defined } @partial), 0, "no entries for known obj collapse" );
    }

    {
        my @partial = eval { $v->collapse_known_objects($foo->bar) };
        is( $@, "", "no error" );
        is( scalar(grep { defined } @partial), 1, "one entry for known obj collapse" );
    }

    $v->resolver->object_to_id($foo->bar);

    my @entries = $v->collapse_objects($foo);

    is( scalar(@entries), 2, "two entries" );

    my $id = $entries[0]->id;
    my $other_id = $entries[1]->id;

    is( $entries[0]->class, 'Foo', "class" );

    is_deeply(
        $entries[0]->data,
        {
            bar => KiokuDB::Reference->new( id => $other_id ),
            id  => "oink",
            zot => "zot",
        },
        "Foo object",
    );

    is_deeply(
        $entries[1]->data,
        {
            id => 3,
            blah => {
                oink => 3
            },
        },
        "Bar object",
    );
}

{
    my $v = KiokuDB::Collapser->new(
        resolver => KiokuDB::Resolver->new(
            live_objects => KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $x = { name => "shared" };

    # shared values must be assigned a UID
    my $bar = Bar->new(
        id => 5,
        blah => [ $x, $x ],
    );

    my @entries = $v->collapse_objects($bar);

    is( scalar(@entries), 2, "two entries" );

    my $id = $entries[0]->id;
    my $other_id = $entries[1]->id;

    is_deeply(
        $entries[0]->data,
        {
            id => 5,
            blah => [
                KiokuDB::Reference->new( id => $other_id ),
                KiokuDB::Reference->new( id => $other_id ),
            ],
        },
        "parent object",
    );

    is_deeply(
        $entries[1]->data,
        {
            name => "shared",
        },
        "shared ref",
    );
}

{
    # circular ref
    my $v = KiokuDB::Collapser->new(
        resolver => KiokuDB::Resolver->new(
            live_objects => KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $foo = Foo->new(
        id  => "oink",
        zot => "zot",
        bar => Bar->new(
            id => 3,
        ),
    );

    $foo->bar->blah($foo);

    my @entries = $v->collapse_objects($foo);

    is( scalar(@entries), 2, "two entries" );

    my $id = $entries[0]->id;
    my $other_id = $entries[1]->id;

    is( $entries[0]->class, 'Foo', "class" );

    is_deeply(
        $entries[0]->data,
        {
            bar => KiokuDB::Reference->new( id => $other_id ),
            id  => "oink",
            zot => "zot",
        },
        "Foo object",
    );

    is_deeply(
        $entries[1]->data,
        {
            id => 3,
            blah => KiokuDB::Reference->new( id => $id ),
        },
        "Bar object",
    );
}

{
    my $v = KiokuDB::Collapser->new(
        resolver => KiokuDB::Resolver->new(
            live_objects => KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $x = { name => "shared" };

    # shared values must be assigned a UID
    my $bar = Bar->new(
        id => 5,
        blah => [ $x, $x ],
    );

    weaken($bar->blah->[0]);

    my @entries = $v->collapse_objects($bar);

    is( scalar(@entries), 2, "two entries" );

    my $id = $entries[0]->id;
    my $other_id = $entries[1]->id;

    is_deeply(
        $entries[0]->data,
        {
            id => 5,
            blah => [
                KiokuDB::Reference->new( id => $other_id, is_weak => 1 ),
                KiokuDB::Reference->new( id => $other_id ),
            ],
        },
        "parent object",
    );

    is_deeply(
        $entries[1]->data,
        {
            name => "shared",
        },
        "shared ref",
    );
}

{
    my $v = KiokuDB::Collapser->new(
        resolver => KiokuDB::Resolver->new(
            live_objects => KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $x = { name => "shared" };

    # shared values must be assigned a UID
    my $bar = Bar->new(
        id => 5,
        blah => [ $x, $x ],
    );

    # second one is weak
    weaken($bar->blah->[1]);

    my @entries = $v->collapse_objects($bar);

    is( scalar(@entries), 2, "two entries" );

    my $id = $entries[0]->id;
    my $other_id = $entries[1]->id;

    is_deeply(
        $entries[0]->data,
        {
            id => 5,
            blah => [
                KiokuDB::Reference->new( id => $other_id ),
                KiokuDB::Reference->new( id => $other_id, is_weak => 1 ),
            ],
        },
        "parent object",
    );

    is_deeply(
        $entries[1]->data,
        {
            name => "shared",
        },
        "shared ref",
    );
}

{
    my $v = KiokuDB::Collapser->new(
        resolver => KiokuDB::Resolver->new(
            live_objects => KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $data = { };
    $data->{self} = $data;

    my $obj = Foo->new( bar => $data );

    $v->resolver->object_to_id($obj);

    my @partial = eval { $v->collapse_known_objects($obj) };
    is_deeply( $@, { unknown => $data }, "error" );
    is( scalar(grep { defined } @partial), 0, "no entries for known obj collapse with circular simple structure" );
}

{
    my $obj = Foo->new( bar => { foo => "hello" } );

    {
        my $v = KiokuDB::Collapser->new(
            resolver => KiokuDB::Resolver->new(
                live_objects => KiokuDB::LiveObjects->new
            ),
            compact => 0,
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new
            ),
        );

        my @entries = $v->collapse_objects($obj);
        is( scalar(@entries), 2, "two entries" );
    }

    {
        my $v = KiokuDB::Collapser->new(
            resolver => KiokuDB::Resolver->new(
                live_objects => KiokuDB::LiveObjects->new
            ),
            compact => 1,
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new
            ),
        );

        my @entries = $v->collapse_objects($obj);
        is( scalar(@entries), 1, "one entry with compacter" );
    }
}

{
    my $obj = Foo->new( foo => "one", bar => Foo->new( foo => "two" ) );

    {
        my $v = KiokuDB::Collapser->new(
            resolver => KiokuDB::Resolver->new(
                live_objects => KiokuDB::LiveObjects->new
            ),
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new
            ),
        );

        {
            my ( $entries, @ids ) = $v->collapse( objects => [ $obj ] );
            is( scalar(keys %$entries), 2, "two entries for deep collapse" );
            is( scalar(@ids), 1, "one root set ID" );
        }

        {
            my ( $entries, @ids ) = $v->collapse( objects => [ $obj ], shallow => 1 );
            is( scalar(keys %$entries), 1, "one entry for shallow collapse" );
            is( scalar(@ids), 1, "one root set ID" );
        }
    }
}
