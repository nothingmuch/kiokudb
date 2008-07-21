#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use Scalar::Util qw(weaken isweak);

use ok 'MooseX::Storage::Directory::Collapser';
use ok 'MooseX::Storage::Directory::Resolver';
use ok 'MooseX::Storage::Directory::LiveObjects';

{
    package Foo;
    use Moose;

    # check reserved field clashes
    has id => ( is => "rw" );

    has bar => ( is => "rw" );

    has zot => ( is => "rw" );

    package Bar;
    use Moose;

    has id => ( is => "rw", isa => "Int" );

    has blah => ( is  => "rw" );
}

{
    my $v = MooseX::Storage::Directory::Collapser->new(
        resolver => MooseX::Storage::Directory::Resolver->new(
            live_objects => MooseX::Storage::Directory::LiveObjects->new
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

    my @entries = $v->collapse_objects($foo);

    is( scalar(@entries), 2, "two entries" );

    my $id = $entries[0]->id;
    my $other_id = $entries[1]->id;

    ok(  $entries[0]->root, "first entry is a root entry" );
    ok( !$entries[1]->root, "second entry is not" );

    is( $entries[0]->class->name, 'Foo', "metaclass" );

    is_deeply(
        $entries[0]->data,
        {
            bar => MooseX::Storage::Directory::Reference->new( id => $other_id ),
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
    my $v = MooseX::Storage::Directory::Collapser->new(
        resolver => MooseX::Storage::Directory::Resolver->new(
            live_objects => MooseX::Storage::Directory::LiveObjects->new
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
                MooseX::Storage::Directory::Reference->new( id => $other_id ),
                MooseX::Storage::Directory::Reference->new( id => $other_id ),
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
    my $v = MooseX::Storage::Directory::Collapser->new(
        resolver => MooseX::Storage::Directory::Resolver->new(
            live_objects => MooseX::Storage::Directory::LiveObjects->new
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

    ok(  $entries[0]->root, "first entry is a root entry" );
    ok( !$entries[1]->root, "second entry is not" );

    is( $entries[0]->class->name, 'Foo', "metaclass" );

    is_deeply(
        $entries[0]->data,
        {
            bar => MooseX::Storage::Directory::Reference->new( id => $other_id ),
            id  => "oink",
            zot => "zot",
        },
        "Foo object",
    );

    is_deeply(
        $entries[1]->data,
        {
            id => 3,
            blah => MooseX::Storage::Directory::Reference->new( id => $id ),
        },
        "Bar object",
    );
}

{
    my $v = MooseX::Storage::Directory::Collapser->new(
        resolver => MooseX::Storage::Directory::Resolver->new(
            live_objects => MooseX::Storage::Directory::LiveObjects->new
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
                MooseX::Storage::Directory::Reference->new( id => $other_id, is_weak => 1 ),
                MooseX::Storage::Directory::Reference->new( id => $other_id ),
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
    my $v = MooseX::Storage::Directory::Collapser->new(
        resolver => MooseX::Storage::Directory::Resolver->new(
            live_objects => MooseX::Storage::Directory::LiveObjects->new
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
                MooseX::Storage::Directory::Reference->new( id => $other_id ),
                MooseX::Storage::Directory::Reference->new( id => $other_id, is_weak => 1 ),
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
