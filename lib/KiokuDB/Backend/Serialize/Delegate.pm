#!/usr/bin/perl

package KiokuDB::Backend::Serialize::Delegate;
use Moose::Role;

use KiokuDB::Serializer;

use namespace::clean -except => 'meta';

has serializer => (
    isa     => "KiokuDB::Serializer",
    is      => "ro",
    coerce  => 1,
    default => "storable",
    handles => [qw(serialize deserialize)],
);

__PACKAGE__

__END__
