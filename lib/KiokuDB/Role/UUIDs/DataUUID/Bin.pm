#!/usr/bin/perl

package KiokuDB::Role::UUIDs::DataUUID::Bin;
use Moose::Role;

use Data::UUID;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Role::UUIDs::Bin);

my $uuid_gen = Data::UUID->new;

sub generate_uuid { $uuid_gen->create_bin }

sub uuid_to_string { $uuid_gen->to_string($_[1]) }
sub string_to_uuid { $uuid_gen->from_string($_[1]) }

__PACKAGE__

__END__
