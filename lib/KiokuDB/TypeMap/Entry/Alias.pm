#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Alias;
use Moose;

use namespace::clean -except => 'meta';

has to => (
    isa => "Str",
    is  => "ro",
    required => 1,
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
