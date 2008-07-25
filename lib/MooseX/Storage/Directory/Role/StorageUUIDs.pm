#!/usr/bin/perl

package MooseX::Storage::Directory::Role::StorageUUIDs;
use Moose::Role;

use MooseX::Storage::Directory ();

use namespace::clean -except => 'meta';

with (
    qw(MooseX::Storage::Directory::Role::UUIDs),
    join("::", __PACKAGE__, MooseX::Storage::Directory::RUNTIME_BINARY_UUIDS() ? "Bin" : "Str" )
);

# controls whether or not UIDs are binary in the storage (where possible)
has binary_uuids => (
    isa => "Bool",
    is  => "rw",
    default => 0,
);

__PACKAGE__

__END__

