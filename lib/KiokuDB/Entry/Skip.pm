#!/usr/bin/perl

package KiokuDB::Entry::Skip;
use Moose;

use namespace::clean -except => 'meta';

has prev => (
    isa => "KiokuDB::Entry",
    is  => "ro",
    handles => [qw(id)],
);

has root => (
    isa => "Bool",
    is  => "rw",
    predicate => "has_root",
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
