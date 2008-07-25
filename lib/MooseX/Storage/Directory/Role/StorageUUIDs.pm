#!/usr/bin/perl

package MooseX::Storage::Directory::Role::StorageUUIDs;
use Moose::Role;

use MooseX::Storage::Directory ();

use namespace::clean -except => 'meta';

with qw(MooseX::Storage::Directory::Role::UUIDs);

# controls whether or not UIDs are binary in the storage (where possible)
has binary_uuids => (
    isa => "Bool",
    is  => "rw",
    default => 0,
);

BEGIN {
    # we only need to translate if the runtime UIDs are actually binary
    if ( MooseX::Storage::Directory::RUNTIME_BINARY_UUIDS() ) {
        eval '
            sub format_uid    { $_[0]->binary_uuids ? $_[1] : $_[0]->uuid_to_string($_[1]) }
            sub parse_uid     { $_[0]->binary_uuids ? $_[1] : $_[0]->string_to_uuid($_[1]) }
        ';
    } else {
        eval '
            sub format_uid    { $_[1] }
            sub parse_uid     { $_[1] }
        ';
    }
    die $@ if $@;
}

__PACKAGE__

__END__

