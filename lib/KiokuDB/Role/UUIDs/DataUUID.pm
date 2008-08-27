#!/usr/bin/perl

package KiokuDB::Role::UUIDs::DataUUID;
use Moose::Role;

use KiokuDB ();

use namespace::clean -except => 'meta';

with join("::", __PACKAGE__, KiokuDB::RUNTIME_BINARY_UUIDS() ? "Bin" : "Str" );

__PACKAGE__

__END__
