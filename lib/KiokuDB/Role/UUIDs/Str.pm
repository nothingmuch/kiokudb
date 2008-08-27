#!/usr/bin/perl

package KiokuDB::Role::UUIDs::Str;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Role::UUIDs::Abstract);

sub uuid_to_string { $_[1] }
sub string_to_uuid { $_[1] }

__PACKAGE__

__END__
