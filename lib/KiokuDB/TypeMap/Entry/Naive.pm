#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Naive;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
