#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

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
    use base qw(Class::Accessor);

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
