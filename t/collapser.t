#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use Scalar::Util qw(weaken isweak);
use Storable qw(dclone);

use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::Resolver';
use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::TypeMap';
use ok 'KiokuDB::TypeMap::Resolver';
use ok 'KiokuDB::TypeMap::Entry::MOP';
use ok 'KiokuDB::TypeMap::Entry::Callback';

use Tie::RefHash;

{
    package Foo;
    use Moose;

    # check reserved field clashes
    has id => ( is => "rw" );

    has bar => ( is => "rw" );

    has zot => ( is => "rw" );

    has moof => ( is => "rw" );

    __PACKAGE__->meta->make_immutable;

    package Bar;
    use Moose;

    has id => ( is => "rw", isa => "Int" );

    has blah => ( is  => "rw" );
}

{
    my $v = KiokuDB::Collapser->new(
        resolver => KiokuDB::Resolver->new(
            live_objects => my $lo = KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $s = $lo->new_scope;

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
            live_objects => my $lo = KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $s = $lo->new_scope;

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
            live_objects => my $lo = KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $s = $lo->new_scope;

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
            live_objects => my $lo = KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $s = $lo->new_scope;

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
            live_objects => my $lo = KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $s = $lo->new_scope;

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
            live_objects => my $lo = KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new
        ),
    );

    my $s = $lo->new_scope;

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
                live_objects => my $lo = KiokuDB::LiveObjects->new
            ),
            compact => 0,
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new
            ),
        );

        my $s = $lo->new_scope;

        my @entries = $v->collapse_objects($obj);
        is( scalar(@entries), 2, "two entries" );
    }

    {
        my $v = KiokuDB::Collapser->new(
            resolver => KiokuDB::Resolver->new(
                live_objects => my $lo = KiokuDB::LiveObjects->new
            ),
            compact => 1,
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new
            ),
        );

        my $s = $lo->new_scope;

        my @entries = $v->collapse_objects($obj);
        is( scalar(@entries), 1, "one entry with compacter" );
    }
}

{
    my $obj = Foo->new( foo => "one", bar => Foo->new( foo => "two" ) );

    {
        my $v = KiokuDB::Collapser->new(
            resolver => KiokuDB::Resolver->new(
                live_objects => my $lo = KiokuDB::LiveObjects->new
            ),
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new
            ),
        );

        my $s = $lo->new_scope;

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

{
    my $obj = Foo->new(
        zot => "one",
        bar => Bar->new( blah => "two" )
    );

    {
        my $v = KiokuDB::Collapser->new(
            resolver => KiokuDB::Resolver->new(
                live_objects => my $lo = KiokuDB::LiveObjects->new
            ),
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new(
                    entries => {
                        Bar => KiokuDB::TypeMap::Entry::MOP->new(
                            intrinsic => 1,
                        ),
                    },
                ),
            ),
        );

        my $s = $lo->new_scope;

        my ( $entries, @ids ) = $v->collapse( objects => [ $obj ] );
        is( scalar(keys %$entries), 1, "one entries for deep collapse with intrinsic value" );
        is( scalar(@ids), 1, "one root set ID" );

        is_deeply(
            $entries->{$ids[0]}->data,
            {
                zot => "one",
                bar => KiokuDB::Entry->new(
                    class => "Bar",
                    data  => { blah => "two" },
                ),
            },
            "intrinsic entry data",
        );
    }
}

{
    tie my %h, 'Tie::RefHash';

    $h{Bar->new( blah => "two" )} = "bar";

    my $obj = Foo->new(
        bar => \%h,
    );

    {
        my $v = KiokuDB::Collapser->new(
            resolver => KiokuDB::Resolver->new(
                live_objects => my $lo = KiokuDB::LiveObjects->new
            ),
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new(
                    entries => {
                        'Tie::RefHash' => KiokuDB::TypeMap::Entry::Callback->new(
                            intrinsic => 1,
                            collapse  => "STORABLE_freeze",
                            expand    => "STORABLE_thaw",
                        ),
                    },
                ),
            ),
        );

        my $s = $lo->new_scope;

        my ( $entries, @ids ) = $v->collapse( objects => [ $obj ] );
        is( scalar(@ids), 1, "one root set ID" );

        my $root = delete $entries->{$ids[0]};
        my $key  = (values %$entries)[0];

        my $t = Tie::RefHash->TIEHASH( KiokuDB::Reference->new( id => $key->id ) => "bar" );

        is_deeply(
            dclone($root),
            KiokuDB::Entry->new(
                id    => $ids[0],
                class => "Foo",
                data  => {
                    bar => KiokuDB::Entry->new(
                        tied => "HASH",
                        data => KiokuDB::Entry->new(
                            class => "Tie::RefHash",
                            data  => [ $t->STORABLE_freeze ],
                        ),
                    ),
                },
            ),
            "intrinsic collapsing of Tie::RefHash",
        );
    }
}

{
    tie my %h, 'Tie::RefHash';

    $h{Bar->new( blah => "two" )} = "bar";

    my $obj = Foo->new(
        bar => \%h,
    );

    {
        my $v = KiokuDB::Collapser->new(
            resolver => KiokuDB::Resolver->new(
                live_objects => my $lo = KiokuDB::LiveObjects->new
            ),
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new(
                    entries => {
                        'Tie::RefHash' => KiokuDB::TypeMap::Entry::Callback->new(
                            collapse  => "STORABLE_freeze",
                            expand    => "STORABLE_thaw",
                        ),
                    },
                ),
            ),
        );

        my $s = $lo->new_scope;

        my ( $entries, @ids ) = $v->collapse( objects => [ $obj ] );
        is( scalar(@ids), 1, "one root set ID" );

        my $root = $entries->{$ids[0]};
        my $tie  = (grep { $_->class eq 'Tie::RefHash' } values %$entries)[0];

        is_deeply(
            dclone($root),
            KiokuDB::Entry->new(
                id    => $ids[0],
                class => "Foo",
                data  => {
                    bar => KiokuDB::Entry->new(
                        tied => "HASH",
                        data => KiokuDB::Reference->new( id => $tie->id ),
                    ),
                },
            ),
            "first class collapsing of Tie::RefHash",
        );
    }
}

{
    my $bar = Bar->new( blah => "shared" );

    my $foo_1 = Foo->new(
        zot => "one",
        bar => $bar,
    );

    my $foo_2 = Foo->new(
        zot => "two",
        bar => $bar,
    );

    my $foo_3 = Foo->new(
        zot => "three",
        bar => $bar,
    );

    my $foo_4 = Foo->new(
        zot => "two",
        bar => $bar,
        moof => [ Bar->new( blah => "yay" ), $bar ],
    );

    my $v = KiokuDB::Collapser->new(
        resolver => KiokuDB::Resolver->new(
            live_objects => my $lo = KiokuDB::LiveObjects->new
        ),
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new(),
        ),
    );

    my $s = $lo->new_scope;

    {
        my ( $entries, @ids ) = $v->collapse( objects => [ $bar ], only_new => 1 );

        is( scalar(keys %$entries), 1, "one entry" );
        is( scalar(@ids), 1, "one root set ID" );

        is( $entries->{$ids[0]}->class, "Bar", "class" );

        $lo->update_entries( values %$entries );
    }

    {
        my ( $entries, @ids ) = $v->collapse( objects => [ $foo_1 ], only_new => 1 );

        is( scalar(keys %$entries), 1, "one entry with only_new" );
        is( scalar(@ids), 1, "one root set ID" );

        is( $entries->{$ids[0]}->class, "Foo", "class" );

        $lo->update_entries( values %$entries );
    }

    {
        my ( $entries, @ids ) = $v->collapse( objects => [ $foo_2 ] );

        is( scalar(keys %$entries), 2, "two entries" );
        is( scalar(@ids), 1, "one root set ID" );

        is( $entries->{$ids[0]}->class, "Foo", "class" );

        $lo->update_entries( values %$entries );
    }

    {
        $lo->insert( foo_3 => $foo_3 );

        my ( $entries, @ids ) = $v->collapse( objects => [ $foo_3 ], only_new => 1 );

        is( $ids[0], "foo_3", "custom ID for object" );

        is( scalar(keys %$entries), 1, "one entry" );
        is( scalar(@ids), 1, "one root set ID" );

        is( $entries->{$ids[0]}->class, "Foo", "class" );

        $lo->update_entries( values %$entries );
    }

    {
        my ( $entries, @ids ) = $v->collapse( objects => [ $foo_4 ], only_new => 1 );

        is( scalar(keys %$entries), 2, "two entries" );
        is( scalar(@ids), 1, "one root set ID" );

        is( $entries->{$ids[0]}->class, "Foo", "class" );

        ok( !exists($entries->{$lo->object_to_id($bar)}), "known object doesn't exist in entry set" );

        is_deeply(
            $entries->{$ids[0]}->data->{moof},
            [
                KiokuDB::Reference->new( id => $lo->object_to_id($foo_4->moof->[0]) ),
                KiokuDB::Reference->new( id => $lo->object_to_id($bar) ),
            ],
        );

        $lo->update_entries( values %$entries );
    }
}
