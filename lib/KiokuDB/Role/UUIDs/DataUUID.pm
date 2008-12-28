#!/usr/bin/perl

package KiokuDB::Role::UUIDs::DataUUID;
use Moose::Role;

use Data::UUID;

use namespace::clean -except => 'meta';

my $uuid_gen = Data::UUID->new;

sub generate_uuid { $uuid_gen->create_str }

__PACKAGE__

__END__
