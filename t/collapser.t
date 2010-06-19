#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Try::Tiny;

use Scalar::Util qw(weaken isweak);
use Storable qw(dclone);

use ok 'KiokuDB::Entry';
use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::TypeMap';
use ok 'KiokuDB::TypeMap::Resolver';
use ok 'KiokuDB::TypeMap::Entry::MOP';
use ok 'KiokuDB::TypeMap::Entry::Callback';
use ok 'KiokuDB::TypeMap::Entry::Ref';
use ok 'KiokuDB::Backend::Hash';

sub KiokuDB::Entry::BUILD { shift->root }; # force building of root for is_deeply
$_->make_mutable, $_->make_immutable for KiokuDB::Entry->meta; # recreate new


use Tie::RefHash;

sub unknown_ok (&@) {
    my ( $block, @objects ) = @_;

    local $@ = "";
    try {
        $block->();
        fail("should have died");
    } catch {
        is_deeply( $_, KiokuDB::Error::UnknownObjects->new( objects => \@objects), "correct error" );
    };
}

{
    package KiokuDB_Test_Foo;
    use Moose;

    # check reserved field clashes
    has id => ( is => "rw" );

    has bar => ( is => "rw" );

    has zot => ( is => "rw" );

    has moof => ( is => "rw" );

    __PACKAGE__->meta->make_immutable;

    package KiokuDB_Test_Bar;
    use Moose;

    has id => ( is => "rw", isa => "Int" );

    has blah => ( is  => "rw" );
}

{
    my $v = KiokuDB::Collapser->new(
        backend => KiokuDB::Backend::Hash->new,
        live_objects => my $lo = KiokuDB::LiveObjects->new,
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new(
                entries => {
                    ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                    HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                },
            ),
        ),
    );

    my $s = $lo->new_scope;

    my $foo = KiokuDB_Test_Foo->new(
        id  => "oink",
        zot => "zot",
        bar => KiokuDB_Test_Bar->new(
            id => 3,
            blah => {
                oink => 3
            },
        ),
    );
 
    unknown_ok { $v->collapse( objects => [ $foo ], only_known => 1 ) } $foo;

    {
        my $obj = KiokuDB_Test_Foo->new( bar => $foo->bar );

        $v->live_objects->insert( foo => $obj );

        unknown_ok { $v->collapse( objects => [ $obj ], only_known => 1 ) } $foo->bar;
    }

    $v->live_objects->insert( bar => $foo->bar );

    unknown_ok { $v->collapse( objects => [ $foo ], only_known => 1 ) } $foo;

    lives_ok {
        my ( $buffer ) = $v->collapse( objects => [ $foo->bar ], only_known => 1 );
        isa_ok( $buffer, "KiokuDB::Collapser::Buffer" );
        is( scalar(values %{ $buffer->_entries }), 1, "one entry for known obj collapse" );
    };

    my ( $buffer, $id, @rest ) = $v->collapse( objects => [ $foo ] );

    ok( $id, "got an id" );

    is( scalar(@rest), 0, "no other return values" );

    my @entries = sort { $a->id eq $id ? -1 : 1 } $buffer->entries;

    my $other_id = $entries[1]->id;

    is( scalar(@entries), 2, "two entries" );

    is( $entries[0]->class, 'KiokuDB_Test_Foo', "class" );

    is_deeply(
        $entries[0]->data,
        {
            bar => KiokuDB::Reference->new( id => $other_id ),
            id  => "oink",
            zot => "zot",
        },
        "KiokuDB_Test_Foo object",
    );

    is_deeply(
        $entries[1]->data,
        {
            id => 3,
            blah => {
                oink => 3
            },
        },
        "KiokuDB_Test_Bar object",
    );
}

{
    my $v = KiokuDB::Collapser->new(
        backend => KiokuDB::Backend::Hash->new,
        live_objects => my $lo = KiokuDB::LiveObjects->new,
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new(
                entries => {
                    ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                    HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                },
            ),
        ),
    );

    my $s = $lo->new_scope;

    my $x = { name => "shared" };

    # shared values must be assigned a UID
    my $bar = KiokuDB_Test_Bar->new(
        id => 5,
        blah => [ $x, $x ],
    );

    my ( $buffer, $id ) = $v->collapse( objects => [ $bar ] );

    my @entries = sort { $a->id eq $id ? -1 : 1 } $buffer->entries;

    is( scalar(@entries), 2, "two entries" );

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
        backend => KiokuDB::Backend::Hash->new,
        live_objects => my $lo = KiokuDB::LiveObjects->new,
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new(
                entries => {
                    ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                    HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                },
            ),
        ),
    );

    my $s = $lo->new_scope;

    my $foo = KiokuDB_Test_Foo->new(
        id  => "oink",
        zot => "zot",
        bar => KiokuDB_Test_Bar->new(
            id => 3,
        ),
    );

    $foo->bar->blah($foo);

    my ( $buffer, $id ) = $v->collapse( objects => [ $foo ] );

    my @entries = sort { $a->id eq $id ? -1 : 1 } $buffer->entries;

    is( scalar(@entries), 2, "two entries" );

    my $other_id = $entries[1]->id;

    is( $entries[0]->class, 'KiokuDB_Test_Foo', "class" );

    is_deeply(
        $entries[0]->data,
        {
            bar => KiokuDB::Reference->new( id => $other_id ),
            id  => "oink",
            zot => "zot",
        },
        "KiokuDB_Test_Foo object",
    );

    is_deeply(
        $entries[1]->data,
        {
            id => 3,
            blah => KiokuDB::Reference->new( id => $id ),
        },
        "KiokuDB_Test_Bar object",
    );
}

{
    my $v = KiokuDB::Collapser->new(
        backend => KiokuDB::Backend::Hash->new,
        live_objects => my $lo = KiokuDB::LiveObjects->new,
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new(
                entries => {
                    ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                    HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                },
            ),
        ),
    );

    my $s = $lo->new_scope;

    my $x = { name => "shared" };

    # shared values must be assigned a UID
    my $bar = KiokuDB_Test_Bar->new(
        id => 5,
        blah => [ $x, $x ],
    );

    weaken($bar->blah->[0]);

    my ( $buffer, $id ) = $v->collapse( objects => [ $bar ] );

    my @entries = sort { $a->id eq $id ? -1 : 1 } $buffer->entries;

    is( scalar(@entries), 2, "two entries" );

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
        backend => KiokuDB::Backend::Hash->new,
        live_objects => my $lo = KiokuDB::LiveObjects->new,
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new(
                entries => {
                    ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                    HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                },
            ),
        ),
    );

    my $s = $lo->new_scope;

    my $x = { name => "shared" };

    # shared values must be assigned a UID
    my $bar = KiokuDB_Test_Bar->new(
        id => 5,
        blah => [ $x, $x ],
    );

    # second one is weak
    weaken($bar->blah->[1]);

    my ( $buffer, $id ) = $v->collapse( objects => [ $bar ] );

    my @entries = sort { $a->id eq $id ? -1 : 1 } $buffer->entries;

    is( scalar(@entries), 2, "two entries" );

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
        backend => KiokuDB::Backend::Hash->new,
        live_objects => my $lo = KiokuDB::LiveObjects->new,
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new(
                entries => {
                    ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                    HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                },
            ),
        ),
    );

    my $s = $lo->new_scope;

    my $data = { };
    $data->{self} = $data;

    my $obj = KiokuDB_Test_Foo->new( bar => $data );

    $v->live_objects->insert( obj => $obj );

    unknown_ok { $v->collapse( objects => [ $obj ], only_known => 1 ) } $data;
}

{
    my $obj = KiokuDB_Test_Foo->new( bar => { foo => "hello" } );

    {
        my $v = KiokuDB::Collapser->new(
            backend => KiokuDB::Backend::Hash->new,
            live_objects => my $lo = KiokuDB::LiveObjects->new,
            compact => 0,
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new(
                    entries => {
                        ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                        HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                    },
                ),
            ),
        );

        my $s = $lo->new_scope;

        my ( $buffer ) = $v->collapse( objects => [ $obj ] );
        is( scalar(keys %{ $buffer->_entries }), 2, "two entries" );
    }

    {
        my $v = KiokuDB::Collapser->new(
            backend => KiokuDB::Backend::Hash->new,
            live_objects => my $lo = KiokuDB::LiveObjects->new,
            compact => 1,
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new(
                    entries => {
                        ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                        HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                    },
                ),
            ),
        );

        my $s = $lo->new_scope;

        my ( $buffer ) = $v->collapse( objects => [ $obj ] );
        is( scalar(keys %{ $buffer->_entries }), 1, "one entry with compacter" );
    }
}

{
    my $obj = KiokuDB_Test_Foo->new( foo => "one", bar => KiokuDB_Test_Foo->new( foo => "two" ) );

    {
        my $v = KiokuDB::Collapser->new(
            backend => KiokuDB::Backend::Hash->new,
            live_objects => my $lo = KiokuDB::LiveObjects->new,
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new(
                    entries => {
                        ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                        HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                    },
                ),
            ),
        );

        my $s = $lo->new_scope;

        {
            my ( $buffer, @ids ) = $v->collapse( objects => [ $obj ] );
            is( scalar(keys %{ $buffer->_entries }), 2, "two entries for deep collapse" );
            is( scalar(@ids), 1, "one root set ID" );

            $buffer->update_entries( in_storage => 1 );
        }

        {
            my ( $buffer, @ids ) = $v->collapse( objects => [ $obj ], shallow => 1 );
            is( scalar(keys %{ $buffer->_entries }), 1, "one entry for shallow collapse" );
            is( scalar(@ids), 1, "one root set ID" );

            $buffer->update_entries( in_storage => 1 );
        }
    }
}

{
    my $obj = KiokuDB_Test_Foo->new(
        zot => "one",
        bar => KiokuDB_Test_Bar->new( blah => "two" )
    );

    {
        my $v = KiokuDB::Collapser->new(
            backend => KiokuDB::Backend::Hash->new,
            live_objects => my $lo = KiokuDB::LiveObjects->new,
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new(
                    entries => {
                        KiokuDB_Test_Bar => KiokuDB::TypeMap::Entry::MOP->new(
                            intrinsic => 1,
                        ),
                        ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                        HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                    },
                ),
            ),
        );

        my $s = $lo->new_scope;

        my ( $buffer, @ids ) = $v->collapse( objects => [ $obj ] );

        my $entries = $buffer->_entries;

        is( scalar(keys %$entries), 1, "one entries for deep collapse with intrinsic value" );
        is( scalar(@ids), 1, "one root set ID" );

        is_deeply(
            $entries->{$ids[0]}->data,
            {
                zot => "one",
                bar => KiokuDB::Entry->new(
                    class => "KiokuDB_Test_Bar",
                    data  => { blah => "two" },
                    object => $obj->bar,
                ),
            },
            "intrinsic entry data",
        );
    }
}

{
    my $bar = KiokuDB_Test_Bar->new( blah => "two" );
    my $obj = KiokuDB_Test_Foo->new(
        zot => "one",
        bar => $bar,
        zot => $bar,
    );

    {
        my $v = KiokuDB::Collapser->new(
            backend => KiokuDB::Backend::Hash->new,
            live_objects => my $lo = KiokuDB::LiveObjects->new,
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new(
                    entries => {
                        KiokuDB_Test_Bar => KiokuDB::TypeMap::Entry::MOP->new(
                            intrinsic => 1,
                        ),
                        ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                        HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                    },
                ),
            ),
        );

        my $s = $lo->new_scope;

        my ( $buffer, @ids ) = $v->collapse( objects => [ $obj ] );

        my $entries = $buffer->_entries;

        is( scalar(keys %$entries), 1, "one entries for deep collapse with shared intrinsic value" );
        is( scalar(@ids), 1, "one root set ID" );

        is_deeply(
            $entries->{$ids[0]}->data,
            {
                zot => "one",
                bar => KiokuDB::Entry->new(
                    class => "KiokuDB_Test_Bar",
                    data  => { blah => "two" },
                    object => $obj->bar,
                ),
                zot => KiokuDB::Entry->new(
                    class => "KiokuDB_Test_Bar",
                    data  => { blah => "two" },
                    object => $obj->bar,
                ),
            },
            "intrinsic entry data",
        );
    }
}

{
    tie my %h, 'Tie::RefHash';

    $h{KiokuDB_Test_Bar->new( blah => "two" )} = "bar";

    my $obj = KiokuDB_Test_Foo->new(
        bar => \%h,
    );

    {
        my $v = KiokuDB::Collapser->new(
            backend => KiokuDB::Backend::Hash->new,
            live_objects => my $lo = KiokuDB::LiveObjects->new,
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new(
                    entries => {
                        'Tie::RefHash' => KiokuDB::TypeMap::Entry::Callback->new(
                            intrinsic => 1,
                            collapse  => "STORABLE_freeze",
                            expand    => sub {
                                my ( $class, @args ) = @_;
                                my $self = bless [], $class;
                                $self->STORABLE_thaw(@args);
                                return $self;
                            }
                        ),
                        ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                        HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                    },
                ),
            ),
        );

        my $s = $lo->new_scope;

        my ( $buffer, @ids ) = $v->collapse( objects => [ $obj ] );
        is( scalar(@ids), 1, "one root set ID" );

        my $entries = $buffer->_entries;
        my $root = delete $entries->{$ids[0]};
        my $key  = (values %$entries)[0];

        my $t = Tie::RefHash->TIEHASH( KiokuDB::Reference->new( id => $key->id ) => "bar" );

        is_deeply(
            dclone($root),
            KiokuDB::Entry->new(
                id    => $ids[0],
                class => "KiokuDB_Test_Foo",
                data  => {
                    bar => KiokuDB::Entry->new(
                        tied => "H",
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

    $h{KiokuDB_Test_Bar->new( blah => "two" )} = "bar";

    my $obj = KiokuDB_Test_Foo->new(
        bar => \%h,
    );

    {
        my $v = KiokuDB::Collapser->new(
            backend => KiokuDB::Backend::Hash->new,
            live_objects => my $lo = KiokuDB::LiveObjects->new,
            typemap_resolver => KiokuDB::TypeMap::Resolver->new(
                typemap => KiokuDB::TypeMap->new(
                    entries => {
                        'Tie::RefHash' => KiokuDB::TypeMap::Entry::Callback->new(
                            collapse  => "STORABLE_freeze",
                            expand    => "STORABLE_thaw",
                        ),
                        ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                        HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                    },
                ),
            ),
        );

        my $s = $lo->new_scope;

        my ( $buffer, @ids ) = $v->collapse( objects => [ $obj ] );
        is( scalar(@ids), 1, "one root set ID" );

        my $entries = $buffer->_entries;

        my $root = $entries->{$ids[0]};
        my $tie  = (grep { $_->class eq 'Tie::RefHash' } values %$entries)[0];

        is_deeply(
            dclone($root),
            KiokuDB::Entry->new(
                id    => $ids[0],
                class => "KiokuDB_Test_Foo",
                data  => {
                    bar => KiokuDB::Entry->new(
                        tied => "H",
                        data => KiokuDB::Reference->new( id => $tie->id ),
                    ),
                },
            ),
            "first class collapsing of Tie::RefHash",
        );
    }
}

{
    my $bar = KiokuDB_Test_Bar->new( blah => "shared" );

    my $foo_1 = KiokuDB_Test_Foo->new(
        zot => "one",
        bar => $bar,
    );

    my $foo_2 = KiokuDB_Test_Foo->new(
        zot => "two",
        bar => $bar,
    );

    my $foo_3 = KiokuDB_Test_Foo->new(
        zot => "three",
        bar => $bar,
    );

    my $foo_4 = KiokuDB_Test_Foo->new(
        zot => "two",
        bar => $bar,
        moof => [ KiokuDB_Test_Bar->new( blah => "yay" ), $bar ],
    );

    my $v = KiokuDB::Collapser->new(
        backend => KiokuDB::Backend::Hash->new,
        live_objects => my $lo = KiokuDB::LiveObjects->new,
        typemap_resolver => KiokuDB::TypeMap::Resolver->new(
            typemap => KiokuDB::TypeMap->new(
                entries => {
                    ARRAY => KiokuDB::TypeMap::Entry::Ref->new,
                    HASH  => KiokuDB::TypeMap::Entry::Ref->new,
                },
            ),
        ),
    );

    my $s = $lo->new_scope;

    {
        my ( $buffer, @ids ) = $v->collapse( objects => [ $bar ], only_in_storage => 1 );

        my $entries = $buffer->_entries;

        is( scalar(keys %$entries), 1, "one entry" );
        is( scalar(@ids), 1, "one root set ID" );

        is( $entries->{$ids[0]}->class, "KiokuDB_Test_Bar", "class" );

        $buffer->update_entries( in_storage => 1 );
    }

    {
        my ( $buffer, @ids ) = $v->collapse( objects => [ $foo_1 ], only_in_storage => 1 );

        my $entries = $buffer->_entries;

        is( scalar(keys %$entries), 1, "one entry with only_in_storage" );
        is( scalar(@ids), 1, "one root set ID" );

        is( $entries->{$ids[0]}->class, "KiokuDB_Test_Foo", "class" );

        $buffer->update_entries( in_storage => 1 );
    }

    {
        my ( $buffer, @ids ) = $v->collapse( objects => [ $foo_2 ] );

        my $entries = $buffer->_entries;

        is( scalar(keys %$entries), 2, "two entries" );
        is( scalar(@ids), 1, "one root set ID" );

        is( $entries->{$ids[0]}->class, "KiokuDB_Test_Foo", "class" );

        $buffer->update_entries( in_storage => 1 );
    }

    {
        $lo->insert( foo_3 => $foo_3 );

        my ( $buffer, @ids ) = $v->collapse( objects => [ $foo_3 ], only_in_storage => 1 );

        my $entries = $buffer->_entries;

        is( $ids[0], "foo_3", "custom ID for object" );

        is( scalar(keys %$entries), 1, "one entry" );
        is( scalar(@ids), 1, "one root set ID" );

        is( $entries->{$ids[0]}->class, "KiokuDB_Test_Foo", "class" );

        $buffer->update_entries( in_storage => 1 );
    }

    lives_ok {
        my ( $buffer, @ids ) = $v->collapse( objects => [ $foo_4 ], only_in_storage => 1 );

        my $entries = $buffer->_entries;

        is( scalar(keys %$entries), 2, "two entries" );
        is( scalar(@ids), 1, "one root set ID" );

        is( $entries->{$ids[0]}->class, "KiokuDB_Test_Foo", "class" );

        ok( !exists($entries->{$lo->object_to_id($bar)}), "known object doesn't exist in entry set" );

        $buffer->update_entries( in_storage => 1 );

        is_deeply(
            $entries->{$ids[0]}->data->{moof},
            [
                KiokuDB::Reference->new( id => $lo->object_to_id($foo_4->moof->[0]) ),
                KiokuDB::Reference->new( id => $lo->object_to_id($bar) ),
            ],
            "references",
        );
    };
}


done_testing;
