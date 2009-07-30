#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Moose;

use Scalar::Util qw(reftype);

use ok 'KiokuDB::TypeMap';
use ok 'KiokuDB::TypeMap::Default::Storable';
use ok 'KiokuDB::TypeMap::Resolver';

my $t = KiokuDB::TypeMap::Default::Storable->new;

my $tr = KiokuDB::TypeMap::Resolver->new(
    typemap => $t,
);

isa_ok( $tr, "KiokuDB::TypeMap::Resolver" );

foreach my $class ( qw(DateTime Path::Class::Entity URI Tie::RefHash Authen::Passphrase) ) {
    my $e = $t->resolve($class);

    does_ok( $e, "KiokuDB::TypeMap::Entry", "entry for $class" );

    my $method = $tr->expand_method($class);

    ok( $method, "compiled" );

    is( reftype($method), "CODE", "expand method" );
}

ok( !$t->resolve("JSON::Boolean"), "no JSON::Boolean" );


done_testing;
