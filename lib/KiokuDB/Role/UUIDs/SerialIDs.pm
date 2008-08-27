#!/usr/bin/perl

package KiokuDB::Role::UUIDs::SerialIDs;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Role::UUIDs::Bin
    KiokuDB::Role::UUIDs::Str
);

my $i = "0001"; # so that the first 10k objects sort lexically
sub generate_uuid { $i++ }

__PACKAGE__

__END__
