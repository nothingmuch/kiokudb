#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 41;

use ok 'KiokuDB'; # constants

sub check_role ($) {
    my $role = shift;

    use_ok $role;

    can_ok( $role, qw(
        generate_uuid
        binary_to_uuid
        uuid_to_binary
        string_to_uuid
        uuid_to_string
    ));

    ok( my $id = eval { $role->generate_uuid }, "$role generates UUIDs" );

    is( eval { $role->binary_to_uuid( $role->uuid_to_binary( $id ) ) }, $id, "round trip binary" );
    is( eval { $role->string_to_uuid( $role->uuid_to_string( $id ) ) }, $id, "round trip string" );
}

check_role 'KiokuDB::Role::UUIDs::SerialIDs';

SKIP: {
    skip $@ => 3 * 5, unless eval { require Data::UUID };
    check_role 'KiokuDB::Role::UUIDs::DataUUID::Bin';
    check_role 'KiokuDB::Role::UUIDs::DataUUID::Str';
    check_role 'KiokuDB::Role::UUIDs::DataUUID';
}

SKIP: {
    skip $@ => 3 * 5, unless eval { require Data::UUID::LibUUID };
    check_role 'KiokuDB::Role::UUIDs::LibUUID::Bin';
    check_role 'KiokuDB::Role::UUIDs::LibUUID::Str';
    check_role 'KiokuDB::Role::UUIDs::LibUUID';
}

check_role 'KiokuDB::Role::UUIDs';


