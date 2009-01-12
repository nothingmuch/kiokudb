#!/usr/bin/perl

package KiokuDB::Entry::Skip;
use Moose;

use namespace::clean -except => 'meta';

has prev => (
    isa => "KiokuDB::Entry",
    is  => "ro",
    required => 1,
    handles => [qw(id)],
);

has root => (
    isa => "Bool",
    is  => "rw",
);

has object => (
    isa => "Any",
    is  => "rw",
    weak_ref => 1,
    predicate => "has_object",
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
