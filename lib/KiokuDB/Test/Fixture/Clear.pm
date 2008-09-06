#!/usr/bin/perl

package KiokuDB::Test::Fixture::Clear;
use Moose;

use Test::More;
use Test::Moose;

use KiokuDB::Test::Person;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Test::Fixture);

sub sort { -10 }

sub create {
    my $self = shift;

    return (
        KiokuDB::Test::Person->new( name => "foo" ), 
        KiokuDB::Test::Person->new( name => "bar" ), 
    );
}

sub precheck {
    my $self = shift;

    $self->skip_fixture(ref($self->backend) . " does not implement Clear")
        unless $self->backend->does("KiokuDB::Backend::Clear");
}

sub verify {
    my $self = shift;


    $self->lookup_ok(@{ $self->populate_ids } );

    $self->backend->clear;

    $self->deleted_ok(@{ $self->populate_ids });
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

