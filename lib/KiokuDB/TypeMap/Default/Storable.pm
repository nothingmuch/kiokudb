#!/usr/bin/perl

package KiokuDB::TypeMap::Default::Storable;
use Moose;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::TypeMap);

with qw(KiokuDB::TypeMap::Default::Passthrough);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
