#!/usr/bin/perl

package MooseX::Storage::Directory::Role::StorageUUIDs::Bin;
use Moose::Role;

use namespace::clean -except => 'meta';

sub format_uid { $_[0]->binary_uuids ? $_[1] : $_[0]->uuid_to_string($_[1]) }
sub parse_uid  { $_[0]->binary_uuids ? $_[1] : $_[0]->string_to_uuid($_[1]) }

__PACKAGE__

__END__
