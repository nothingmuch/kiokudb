#!/usr/bin/perl

package KiokuDB::Role::UUIDs;
use Moose::Role;

use KiokuDB ();

use namespace::clean -except => 'meta';

if ( KiokuDB::SERIAL_IDS() ) {
    with qw(KiokuDB::Role::UUIDs::SerialIDs);
} else {
    my $have_libuuid = do { local $@; eval { require Data::UUID::LibUUID; 1 } };

    my $backend = $have_libuuid ? "LibUUID" : "DataUUID";

    with "KiokuDB::Role::UUIDs::$backend";
}

__PACKAGE__

__END__
