#!/usr/bin/perl

package KiokuDB::Test::Person;
use Moose;

use namespace::clean -except => 'meta';

has [qw(name age job)] => (
    isa => "Str",
    is  => "rw",
);

has so => (
    isa => "KiokuDB::Test::Person",
    is  => "rw",
    weak_ref => 1,
);

has [qw(parents kids friends)] => (
    isa => "ArrayRef[KiokuDB::Test::Person]",
    is  => "rw",
    default => sub { [] },
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

