#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use Scalar::Util qw(refaddr reftype blessed);
use Storable qw(dclone);

use ok 'KiokuDB::TypeMap::Entry::Callback';
use ok 'KiokuDB::TypeMap::Resolver';
use ok 'KiokuDB::Collapser';
use ok 'KiokuDB::Linker';
use ok 'KiokuDB::LiveObjects';
use ok 'KiokuDB::Backend::Hash';

use Tie::RefHash;

{
    package Foo;
    use Moose;

    has bar => ( is => "rw" );

    package Bar;
    use Moose;

    has blah => ( is => "rw" );
}

tie my %h, 'Tie::RefHash';

$h{Bar->new( blah => "two" )} = "bar";

my $obj = Foo->new(
    bar => \%h,
);

for my $i ( 0, 1 ) {
    my $tr = KiokuDB::TypeMap::Resolver->new(
        typemap => KiokuDB::TypeMap->new(
            entries => {
                'Tie::RefHash' => KiokuDB::TypeMap::Entry::Callback->new(
                    intrinsic => $i,
                    collapse  => "STORABLE_freeze",
                    expand    => sub {
                        my ( $class, @args ) = @_;
                        my $self = (bless [], $class);
                        $self->STORABLE_thaw(0, @args);
                        return $self;
                    },
                ),
            },
        ),
    );

    my $v = KiokuDB::Collapser->new(
        backend => KiokuDB::Backend::Hash->new,
        live_objects => KiokuDB::LiveObjects->new,
        typemap_resolver => $tr,
    );

    my $l = KiokuDB::Linker->new(
        backend => KiokuDB::Backend::Hash->new,
        live_objects => KiokuDB::LiveObjects->new,
        typemap_resolver => $tr,
    );

    my $sv = $v->live_objects->new_scope;
    my $sl = $l->live_objects->new_scope;

    my ( $buffer, @ids ) = $v->collapse( objects => [ $obj ] );

    my $entries = $buffer->entries;

    is( scalar(@ids), 1, "one root set ID" );

    my $copy = dclone($entries);

    $l->live_objects->insert_entries(values %$entries);

    my $loaded = $l->expand_object($copy->{$ids[0]});

    isa_ok( $loaded, "Foo" );

    is( ref(my $h = $loaded->bar), "HASH", "Foo->bar is a hash" );

    isa_ok( tied(%$h), "Tie::RefHash", "tied to Tie::RefHash" );
}

