#!/usr/bin/perl

package MooseX::Storage::Directory::Test::Person;
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
    isa => "MooseX::Storage::Directory::Test::Person",
    is  => "rw",
);

has parents => (
    isa => "ArrayRef[MooseX::Storage::Directory::Test::Person]",
    is  => "rw",
    default => sub { [] },
);

has kids => (
    isa => "ArrayRef[MooseX::Storage::Directory::Test::Person]",
    is  => "rw",
    default => sub { [] },
);

has friends => (
    isa => "ArrayRef[MooseX::Storage::Directory::Test::Person]",
    is  => "rw",
    default => sub { [] },
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

