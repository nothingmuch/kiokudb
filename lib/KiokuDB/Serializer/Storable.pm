#!/usr/bin/perl

package KiokuDB::Serializer::Storable;
use Moose;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Serializer
    KiokuDB::Backend::Serialize::Storable
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
