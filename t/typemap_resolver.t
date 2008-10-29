#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;

use Scalar::Util qw(reftype);

use ok 'KiokuDB::TypeMap';
use ok 'KiokuDB::TypeMap::Entry::Naive';
use ok 'KiokuDB::TypeMap::Resolver';

{
    package Foo;
    use Moose;

    package Bar;
    use Moose;

    extends qw(Foo);

    package CA;

    package CA::Sub;
    use base qw(CA);
}

my $t = KiokuDB::TypeMap->new(
    entries => {
        CA => KiokuDB::TypeMap::Entry::Naive->new,
    },
);

my $tr = KiokuDB::TypeMap::Resolver->new(
    typemap => $t,
);

isa_ok( $tr, "KiokuDB::TypeMap::Resolver" );

ok( !$tr->resolved("CA"), "not yet resolved" );

my $method = $tr->expand_method("CA");

is( reftype($method), "CODE", "expand method" );

ok( $tr->resolved("CA"), "now it's resolved" );

dies_ok { $tr->expand_method("Hippies") } "no method for non existent class";

dies_ok { $tr->expand_method("CA::Sub") } "no method for unregistered class";

lives_ok { $tr->expand_method("Foo") } "classes with meta do work";

ok( my $method_meta = $tr->expand_method("Foo"), "code" );

is( reftype($method_meta), "CODE", "expand method" );


