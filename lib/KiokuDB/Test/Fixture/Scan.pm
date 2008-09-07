#!/usr/bin/perl

package KiokuDB::Test::Fixture::Scan;
use Moose;

use Test::More;
use Test::Moose;

use KiokuDB::Test::Person;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Test::Fixture);

use constant required_backend_roles => qw(Clear Scan);

sub create {
    my $self = shift;

    ( map { KiokuDB::Test::Person->new(%$_) }
        { name => "foo", age => 3 },
        { name => "bar", age => 3 },
        { name => "gorch", age => 5 },
    );
}

before populate => sub {
    my $self = shift;
    $self->backend->clear;
};

sub verify {
    my $self = shift;

    my $stream = $self->root_set;

    does_ok( $stream, "Data::Stream::Bulk" );

    is_deeply(
        [ sort map { $_->name } $stream->all ],
        [ sort qw(foo bar gorch) ],
        "root set",
    );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

