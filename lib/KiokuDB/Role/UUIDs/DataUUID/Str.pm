#!/usr/bin/perl

package KiokuDB::Role::UUIDs::DataUUID::Str;
use Moose::Role;

use Data::UUID;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Role::UUIDs::Str);

my $uuid_gen = Data::UUID->new;

sub generate_uuid { $uuid_gen->create_str }

sub binary_to_uuid { $uuid_gen->to_string($_[1]) }
sub uuid_to_binary { $uuid_gen->from_string($_[1]) }

__PACKAGE__

__END__
