#!/usr/bin/perl

package MooseX::Storage::Directory::Role::UUIDs::DataUUID;
use Moose::Role;

use MooseX::Storage::Directory ();

use namespace::clean -except => 'meta';

with join("::", __PACKAGE__, MooseX::Storage::Directory::RUNTIME_BINARY_UUIDS() ? "Bin" : "Str" );

__PACKAGE__

__END__
