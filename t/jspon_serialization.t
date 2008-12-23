#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Moose;

use ok 'KiokuDB::Backend::Serialize::JSPON';
use ok 'KiokuDB::Backend::Serialize::JSON';
use ok 'KiokuDB::Entry';
use ok 'KiokuDB::Reference';

{
    package Foo;
    use Moose;

    with qw(KiokuDB::Backend::Serialize::JSON);
}

my $entry = KiokuDB::Entry->new(
    id => "foo",
    class => "Hello",
    root => 1,
    data => {
        id => "id_attribute",
        bar => KiokuDB::Reference->new( id => "bar", is_weak => 1 ),
        foo => { '$ref' => "lala" },
        'public::moose' => 'elk',
    },
);

my $tied = KiokuDB::Entry->new(
    tied => "HASH",
    data => KiokuDB::Entry->new(
        id => "bar",
        data => {
            foo => "bar",
        },
    ),
);

{
    my $x = Foo->new;

    does_ok( $x, "KiokuDB::Backend::TypeMap::Default" );
    does_ok( $x, "KiokuDB::Backend::Serialize" );

    isa_ok( $x->default_typemap, "KiokuDB::TypeMap::Default::JSON" );

    isa_ok( $x->collapser, "KiokuDB::Backend::Serialize::JSPON::Collapser" );

    isa_ok( $x->expander, "KiokuDB::Backend::Serialize::JSPON::Expander" );


    my $jspon = $x->collapse_jspon($entry);

    is_deeply(
        $jspon,
        {
            __CLASS__ => "Hello",
            id        => "foo",
            data      => {
                "public::id"            => "id_attribute",
                bar                     => { '$ref' => "bar.data", weak => 1 },
                foo                     => { 'public::$ref' => "lala" },
                'public::public::moose' => "elk",
            },
            root      => JSON::true,
        },
        "collapsed jspon",
    );

    my $obj = $x->expand_jspon($jspon);

    is_deeply( $obj->data, $entry->data, "expanded jspon" );


    is( $obj->id, "foo", "ID" );
    is( $obj->class, "Hello", "class" );

    ok( !$obj->deleted, "not deleted" );
    ok( $obj->root, "root" );

    my $json = $x->serialize($entry);

    ok( !ref($json), "json is not a ref" );

    ok( !utf8::is_utf8($json), "already encoded (not unicode)" );

    is_deeply( $x->deserialize($json), $entry, "round tripping" );
}

{
    my $x = Foo->new(
        id_field => "_id",
        class_field => "class",
        inline_data => 1,
    );

    my $jspon = $x->collapse_jspon($entry);

    is_deeply(
        $jspon,
        {
            class                   => "Hello",
            _id                     => "foo",
            root                    => JSON::true,
            id                      => "id_attribute",
            bar                     => { '$ref' => "bar", weak => 1 },
            foo                     => { 'public::$ref' => "lala" },
            'public::public::moose' => "elk",
        },
        "collapsed jspon",
    );

    my $obj = $x->expand_jspon($jspon);

    is_deeply( $obj->data, $entry->data, "expanded jspon" );


    is( $obj->id, "foo", "ID" );
    is( $obj->class, "Hello", "class" );

    ok( !$obj->deleted, "not deleted" );
    ok( $obj->root, "root" );
}

{
    my $x = Foo->new;

    my $jspon = $x->collapse_jspon($tied);

    is_deeply(
        $jspon,
        {
            tied => "HASH",
            data => {
                id => "bar",
                data => { foo => "bar" },
            },
        },
        "collapsed jspon",
    );

    my $obj = $x->expand_jspon($jspon);

    isa_ok( $obj->data, "KiokuDB::Entry" );

    is_deeply( $obj->data->data, $tied->data->data, "expanded jspon" );

    ok( !$obj->has_id, "no id" );
    ok( !$obj->has_class, "no class" );

    ok( !$obj->deleted, "not deleted" );
    ok( !$obj->root, "not root" );

}
