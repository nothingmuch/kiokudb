#!/usr/bin/perl

package MooseX::Storage::Directory::Role::StorageUUIDs::Str;
use Moose::Role;

use namespace::clean -except => 'meta';

sub format_uid { $_[1] }
sub parse_uid  { $_[1] }

__PACKAGE__

__END__
