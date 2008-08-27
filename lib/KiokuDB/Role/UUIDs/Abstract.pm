#!/usr/bin/perl

package KiokuDB::Role::UUIDs::Abstract;
use Moose::Role;

use namespace::clean -except => 'meta';

requires qw(
    generate_uuid

    binary_to_uuid
    uuid_to_binary

    string_to_uuid
    uuid_to_string
);

__PACKAGE__

__END__
