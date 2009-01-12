#!/usr/bin/perl

package KiokuDB::Test::Fixture::RootSet;
use Moose;

use Test::More;
use Test::Exception;

use KiokuDB::Test::Person;
use KiokuDB::Test::Company;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Test::Fixture);

sub sort { -50 }

sub create {
    return (
        root_person => KiokuDB::Test::Person->new(
            name    => "blah",
            kids    => [ KiokuDB::Test::Person->new( name => "flarp" ) ],
        ),
    );
}

sub verify {
    my $self = shift;

    $self->txn_lives(sub {
        my $p = $self->lookup_ok("root_person");

        isa_ok( $p, "KiokuDB::Test::Person" );

        $self->root_ok($p);
        $self->not_root_ok($p->kids->[0]);
    });

    $self->no_live_objects;

    $self->txn_lives(sub {
        my $p = $self->lookup_ok("root_person");

        $self->root_ok($p);
        $self->not_root_ok($p->kids->[0]);

        $p->name("pubar");

        $self->update_ok($p);

        $self->root_ok($p);
        $self->not_root_ok($p->kids->[0]);
    });

    $self->no_live_objects;

    $self->txn_lives(sub {
        my $p = $self->lookup_ok("root_person");

        $self->root_ok($p);
        $self->not_root_ok($p->kids->[0]);

        $self->unset_root($p);

        $self->not_root_ok($p, $p->kids->[0]);

        $self->update_ok($p);

        $self->not_root_ok($p, $p->kids->[0]);
    });

    $self->no_live_objects;

    $self->txn_lives(sub {
        my $p = $self->lookup_ok("root_person");

        $self->not_root_ok($p, $p->kids->[0]);

        $self->set_root($p);

        $self->root_ok($p);
        $self->not_root_ok($p->kids->[0]);
    });

    $self->no_live_objects;

    $self->txn_lives(sub {
        my $p = $self->lookup_ok("root_person");

        $self->not_root_ok($p, $p->kids->[0]);

        $self->set_root($p);

        $self->root_ok($p);
        $self->not_root_ok($p->kids->[0]);

        $self->update_ok($p);
    });

    $self->no_live_objects;

    $self->txn_lives(sub {
        my $p = $self->lookup_ok("root_person");

        $self->root_ok($p);
        $self->not_root_ok($p->kids->[0]);
    });
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
