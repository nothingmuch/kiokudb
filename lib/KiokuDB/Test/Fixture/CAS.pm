#!/usr/bin/perl

package KiokuDB::Test::Fixture::CAS;
use Moose;

use Test::More;
use Scalar::Util qw(weaken);

use KiokuDB::Test::Digested;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Test::Fixture);

sub create {
    my $self = shift;

    KiokuDB::Test::Digested->new(
        foo => "pizza",
    );
}

sub verify {
    my $self = shift;

    $self->no_live_objects;

    my $l = $self->directory->live_objects;

    my $cache = $l->cache;

    my $old_value = $l->leak_tracker;

    my $reset = Scope::Guard->new(sub {
        if ( $old_value ) {
            $l->leak_tracker($old_value);
        } else {
            $l->clear_leak_tracker;
        }
    });

    $l->leak_tracker(sub {
        my $i = $Test::Builder::Level || 1;
        $i++ until (caller($i))[1] eq __FILE__;
        local $Test::Builder::Level = $i + 2;
        fail("no leaks");
        diag("leaked @_"),
    });

    my $id = $self->populate_ids->[0];

    $self->txn_lives(sub {
        my $obj = $self->lookup_ok($id);

        is( $obj->digest, $id, "id is object digest" );

        is( $obj->foo, "pizza", "field retained" );
    });

    if ( $cache ) {
        isa_ok( my $cached = $cache->get($id), "KiokuDB::Test::Digested", "cached object" );
        $self->live_objects_are($cached);
        $cache->clear;
    }

    $self->no_live_objects();

    $self->txn_lives(sub {
        # test idempotent insertions
        $self->insert_ok( KiokuDB::Test::Digested->new( foo => "pizza" ) );
    });

    $cache->clear if $cache;
    $self->no_live_objects();

    $self->txn_lives(sub {
        my $obj = $self->lookup_ok($id);

        my $new_id = $self->insert_ok( $obj->clone );

        local $TODO = "ID not yet returned";
        is( $new_id, $id, "idempotent add when instance already live" );
    });

    $cache->clear if $cache;
    $self->no_live_objects();

    $self->txn_lives(sub {
        my $obj = $self->lookup_ok($id);

        my $new_id = $self->insert_ok( $obj->clone( bar => "blah" ) );

        ok( $new_id, "got a new ID" );
        isnt( $new_id, $id, "idempotent add when instance already live" );
    });

    if ( $cache ) {
        isa_ok( my $cached = $cache->get($id), "KiokuDB::Test::Digested", "cached object" );
        $self->live_objects_are($cached);
        $cache->clear;
    }

    $self->no_live_objects();
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
