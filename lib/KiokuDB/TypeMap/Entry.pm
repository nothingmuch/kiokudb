#!/usr/bin/perl

package KiokuDB::TypeMap::Entry;
use Moose::Role;

use namespace::clean -except => 'meta';

has intrinsic => (
    isa => "Bool",
    default => 0,
);

__PACKAGE__

__END__
