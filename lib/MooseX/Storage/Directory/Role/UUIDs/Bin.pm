#!/usr/bin/perl

package MooseX::Storage::Directory::Role::UUIDs::Bin;
use Moose::Role;

use namespace::clean -except => 'meta';

sub binary_to_uuid { $_[1] }
sub uuid_to_binary { $_[1] }

__PACKAGE__

__END__
