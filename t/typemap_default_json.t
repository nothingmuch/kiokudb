#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Moose;

use Scalar::Util qw(reftype);

use ok 'KiokuDB::TypeMap';
use ok 'KiokuDB::TypeMap::Default::JSON';
use ok 'KiokuDB::TypeMap::Resolver';

my $t = KiokuDB::TypeMap::Default::JSON->new;

my $tr = KiokuDB::TypeMap::Resolver->new(
    typemap => $t,
);

isa_ok( $tr, "KiokuDB::TypeMap::Resolver" );

foreach my $class ( qw(DateTime Path::Class::Entity URI Tie::RefHash Authen::Passphrase JSON::Boolean SCALAR) ) {
    my $e = $t->resolve($class);

    does_ok( $e, "KiokuDB::TypeMap::Entry", "entry for $class" );

    my $method = $tr->expand_method($class);

    ok( $method, "compiled" );

    is( reftype($method), "CODE", "expand method" );
}

SKIP: {
    skip "JSON required ($@)", 3 unless eval { require JSON };

    my $json = JSON->new->decode('{ "id": "lala", "data": { "yes": true, "no": false } }');

    {
        package My::Object;
        use Moose;

        has yes => ( is => "ro", default => sub { JSON::true() } );
        has no  => ( is => "ro", default => sub { JSON::false() } );
    }

    my $obj = My::Object->new;

    require KiokuDB::Collapser;
    require KiokuDB::LiveObjects;
    require KiokuDB::Backend::Hash;

    my $l = KiokuDB::LiveObjects->new;

    my $c = KiokuDB::Collapser->new(
        backend => KiokuDB::Backend::Hash->new,
        live_objects => $l,
        typemap_resolver => $tr,
    );

    my $s = $l->new_scope;

    my ( $buffer, $id ) = $c->collapse(objects => [ $obj ]);

    my $entry = $buffer->entries->{$id};

    isa_ok( $entry->data->{yes}, "JSON::Boolean", "boolean passed through" );

}


done_testing;
