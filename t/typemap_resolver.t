#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Scalar::Util qw(reftype);

use ok 'KiokuDB::TypeMap';
use ok 'KiokuDB::TypeMap::Entry::Naive';
use ok 'KiokuDB::TypeMap::Resolver';

{
    package KiokuDB_Test_Foo;
    use Moose;

    package KiokuDB_Test_Bar;
    use Moose;

    extends qw(KiokuDB_Test_Foo);

    package KiokuDB_Test_CA;

    package KiokuDB_Test_CA::Sub;
    use base qw(KiokuDB_Test_CA);
}

my $t = KiokuDB::TypeMap->new(
    entries => {
        KiokuDB_Test_CA => KiokuDB::TypeMap::Entry::Naive->new,
    },
);

my $tr = KiokuDB::TypeMap::Resolver->new(
    typemap => $t,
);

isa_ok( $tr, "KiokuDB::TypeMap::Resolver" );

ok( !$tr->resolved("KiokuDB_Test_CA"), "not yet resolved" );

my $method = $tr->expand_method("KiokuDB_Test_CA");

is( reftype($method), "CODE", "expand method" );

ok( $tr->resolved("KiokuDB_Test_CA"), "now it's resolved" );

dies_ok { $tr->expand_method("Hippies") } "no method for non existent class";

dies_ok { $tr->expand_method("KiokuDB_Test_CA::Sub") } "no method for unregistered class";

lives_ok { $tr->expand_method("KiokuDB_Test_Foo") } "classes with meta do work";

ok( my $method_meta = $tr->expand_method("KiokuDB_Test_Foo"), "code" );

is( reftype($method_meta), "CODE", "expand method" );


done_testing;
