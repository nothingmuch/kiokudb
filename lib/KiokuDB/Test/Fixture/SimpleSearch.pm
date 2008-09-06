#!/usr/bin/perl

package KiokuDB::Test::Fixture::SimpleSearch;
use Moose;

use Test::More;

use KiokuDB::Test::Person;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Test::Fixture);

sub create {
    my $self = shift;

    ( map { KiokuDB::Test::Person->new(%$_) }
        { name => "foo", age => 3 },
        { name => "bar", age => 3 },
        { name => "gorch", age => 5 },
    );
}

sub precheck {
    my $self = shift;

    $self->skip_fixture(ref($self->backend) . " does not implement Query::Simple")
        unless $self->backend->does("KiokuDB::Backend::Query::Simple");
}

sub verify {
    my $self = shift;

}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

