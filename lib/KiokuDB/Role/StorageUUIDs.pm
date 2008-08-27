#!/usr/bin/perl

package KiokuDB::Role::StorageUUIDs;
use Moose::Role;

use KiokuDB ();

use namespace::clean -except => 'meta';

with (
    qw(KiokuDB::Role::UUIDs),
    join("::", __PACKAGE__, KiokuDB::RUNTIME_BINARY_UUIDS() ? "Bin" : "Str" )
);

# controls whether or not UIDs are binary in the storage (where possible)
has binary_uuids => (
    isa => "Bool",
    is  => "rw",
    default => 0,
);

__PACKAGE__

__END__

