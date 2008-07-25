#!/usr/bin/perl

package MooseX::Storage::Directory::Role::UUIDs::LibUUID::Bin;
use Moose::Role;

use Data::UUID::LibUUID;

use namespace::clean -except => 'meta';

with qw(MooseX::Storage::Directory::Role::UUIDs::Bin);

sub generate_uuid { Data::UUID::LibUUID::new_uuid_binary() }

sub uuid_to_string { Data::UUID::LibUUID::uuid_to_string($_[1]) }
sub string_to_uuid { Data::UUID::LibUUID::uuid_to_binary($_[1]) }

__PACKAGE__

__END__
