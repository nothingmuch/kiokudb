#!/usr/bin/perl

package KiokuDB::Test::Fixture::Clear;
use Moose;

use Test::More;
use Test::Moose;

use KiokuDB::Test::Person;

use namespace::clean -except => 'meta';

use constant required_backend_roles => qw(Clear);

with qw(KiokuDB::Test::Fixture);

sub sort { -10 }

sub create {
    my $self = shift;

    return (
        KiokuDB::Test::Person->new( name => "foo" ),
        KiokuDB::Test::Person->new( name => "bar" ),
    );
}

sub verify {
    my $self = shift;


    $self->txn_lives(sub { $self->lookup_ok(@{ $self->populate_ids } ) });

    $self->txn_lives(sub { $self->backend->clear });

    $self->txn_lives(sub { $self->deleted_ok(@{ $self->populate_ids }) });
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

