#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use Storable qw(dclone);

use ok 'KiokuDB::Entry';
use ok 'KiokuDB::Reference';
use ok 'KiokuDB::LiveObjects';

{
    package Foo;
    use Moose;

    has oi => ( is => "rw" );
}

my $x = Foo->new( oi => "vey" );
my $l = KiokuDB::LiveObjects->new;

{
    foreach my $ent (
        KiokuDB::Entry->new(
            id => "foo",
            root => 1,
            class => "Foo",
            data => { oi => "vey" },
            object => $x,
            class_meta => { roles => [qw(Bar)] },
        ),
        KiokuDB::Entry->new(
            id => "bar",
            data => [ 1 .. 3 ],
        ),
        KiokuDB::Entry->new(
            id => "goner",
            deleted => 1
        ),
        KiokuDB::Entry->new(
            id   => "bondage",
            tied => "H",
            data => KiokuDB::Entry->new(
                class => "Foo",
                data => {},
            ),
        ),
        #KiokuDB::Entry->new(
        #    id   => "bondage",
        #    tied => "HASH",
        #    data => KiokuDB::Entry->new(
        #        class => "Foo",
        #        data => {},
        #    ),
        #),
        KiokuDB::Entry->new(
            id => "bar",
            data => [ 1 .. 3 ],
            backend_data => ["lalalal"],
        ),
        KiokuDB::Entry->new(
            id => "bar",
            data => [ 1 .. 3 ],
            prev => KiokuDB::Entry->new( id => "bar" ),
        ),
        ( map { KiokuDB::Entry->new( id => $_, data => { } ) }
            "foo",
            123,
            "la-la",
            "3B19C598-E873-4C65-80BA-0D1C4E961DC9",
            "9170dc3d7a22403e11ff4c8aa1cd14d20c0ebf65",
            pack("H*", "9170dc3d7a22403e11ff4c8aa1cd14d20c0ebf65"),
            "foo,bar",
        ),
    ) {
        my $copy = dclone($ent);

        foreach my $transient ( qw(object prev) ) {
            my $attr = KiokuDB::Entry->meta->find_attribute_by_name($transient);
            ok( !$attr->has_value($copy), "no $transient in copy" );
            $attr->clear_value($ent);
        }

        is( $copy->id, $ent->id, "ID is the same" );

        is_deeply( $copy, $ent, "copy is_deeply orig" );

        is_deeply( dclone($copy), $copy, "round trip of copy" );

        unless ( $ent->id =~ /,/ ) {
            my $new = KiokuDB::Entry->new;

            $new->_unpack( $ent->_pack_old );

            foreach my $field (qw(id class root deleted tied ) ) {
                is( $new->$field, $ent->$field, "$field in old pack format" );
            }
        }
    }
}


my ( $foo, $bar, $gorch ) = map { KiokuDB::Reference->new( id => $_ ) } qw(foo bar gorch);

is_deeply(
    [ KiokuDB::Entry->new( data => $foo )->references ],
    [ $foo ],
    "simple ref",
);

is_deeply(
    [ KiokuDB::Entry->new( data => { foo => $foo } )->references ],
    [ $foo ],
    "simple ref in hash",
);

is_deeply(
    [ sort KiokuDB::Entry->new( data => { foo => [ $foo, $bar ] } )->references ],
    [ sort $foo, $bar ],
    "multiple refs",
);

is_deeply(
    [ KiokuDB::Entry->new( data => { foo => KiokuDB::Entry->new( data => [ $foo ] ) } )->references ],
    [ $foo ],
    "intrinsic entry",
);

is_deeply(
    [ KiokuDB::Entry->new( data => { foo => KiokuDB::Entry->new( data => [ $foo ] ) } )->referenced_ids ],
    [ $foo->id ],
    "intrinsic entry (ids)",
);

is_deeply(
    [ KiokuDB::Entry->new(
        data  => [qw(foo bar)],
        class => 'KiokuDB::Set::Stored',
        id    => 'the_set',
    )->references ],
    [ $foo, $bar ],
    "set entry",
);

is_deeply(
    [ KiokuDB::Entry->new(
        data  => [qw(foo bar)],
        class => 'KiokuDB::Set::Stored',
        id    => 'the_set',
    )->referenced_ids ],
    [ $foo->id, $bar->id ],
    "set entry (ids)",
);

