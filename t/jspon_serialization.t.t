#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Moose;

use ok 'KiokuDB::Backend::Serialize::JSPON';
use ok 'KiokuDB::Entry';
use ok 'KiokuDB::Reference';

{
    package Foo;
    use Moose;

    with qw(KiokuDB::Backend::Serialize::JSPON);
}

my $x = Foo->new;

does_ok( $x, "KiokuDB::Backend::TypeMap::Default" );

isa_ok( $x->default_typemap, "KiokuDB::TypeMap::Default::JSON" );

isa_ok( $x->collapser, "KiokuDB::Backend::Serialize::JSPON::Collapser" );

isa_ok( $x->expander, "KiokuDB::Backend::Serialize::JSPON::Expander" );


my $entry = KiokuDB::Entry->new(
    id => "foo",
    class => "Hello",
    data => {
        id => "id_attribute",
        bar => KiokuDB::Reference->new( id => "bar", is_weak => 1 ),
        foo => { '$ref' => "lala" },
        'public::moose' => 'elk',
    },
);

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
    },
    "collapsed jspon",
);

my $obj = $x->expand_jspon($jspon);

is_deeply( $obj, $entry, "expanded jspon" );

