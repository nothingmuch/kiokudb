#!/usr/bin/perl

package KiokuDB::Serializer::Memory;
use Moose;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::Serialize::Memory
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
