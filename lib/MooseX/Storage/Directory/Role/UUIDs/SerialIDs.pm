#!/usr/bin/perl

package MooseX::Storage::Directory::Role::UUIDs::SerialIDs;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(
    MooseX::Storage::Directory::Role::UUIDs::Bin
    MooseX::Storage::Directory::Role::UUIDs::Str
);

my $i = "0001"; # so that the first 10k objects sort lexically
sub generate_uuid { $i++ }

__PACKAGE__

__END__
