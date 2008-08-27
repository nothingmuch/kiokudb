#!/usr/bin/perl

package KiokuDB::Test::Person;
use Moose;

use namespace::clean -except => 'meta';

has name => (
    isa => "Str",
    is  => "rw",
);

has job => (
    isa => "Str",
    is  => "rw",
);

has so => (
    isa => "KiokuDB::Test::Person",
    is  => "rw",
);

has parents => (
    isa => "ArrayRef[KiokuDB::Test::Person]",
    is  => "rw",
    default => sub { [] },
);

has kids => (
    isa => "ArrayRef[KiokuDB::Test::Person]",
    is  => "rw",
    default => sub { [] },
);

has friends => (
    isa => "ArrayRef[KiokuDB::Test::Person]",
    is  => "rw",
    default => sub { [] },
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

