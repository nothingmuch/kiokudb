#!/usr/bin/perl

package KiokuDB::Serializer::YAML;
use Moose;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Serializer
    KiokuDB::Backend::Serialize::YAML
);


__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
