#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 12;

sub check_role ($) {
    my $role = shift;

    use_ok $role;

    can_ok( $role, 'generate_uuid' );

    ok( my $id = eval { $role->generate_uuid }, "$role generates UUIDs" );
}

check_role 'KiokuDB::Role::UUIDs::SerialIDs';

SKIP: {
    skip $@ => 3 * 5, unless eval { require Data::UUID };
    check_role 'KiokuDB::Role::UUIDs::DataUUID';
}

SKIP: {
    skip $@ => 3 * 5, unless eval { require Data::UUID::LibUUID };
    check_role 'KiokuDB::Role::UUIDs::LibUUID';
}

check_role 'KiokuDB::Role::UUIDs';


