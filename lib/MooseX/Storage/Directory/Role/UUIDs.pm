#!/usr/bin/perl

package MooseX::Storage::Directory::Role::UUIDs;
use Moose::Role;

use MooseX::Storage::Directory ();

use namespace::clean -except => 'meta';

if ( MooseX::Storage::Directory::SERIAL_IDS() ) {
    with qw(MooseX::Storage::Directory::Role::UUIDs::SerialIDs);
} else {
    my $have_libuuid = do { local $@; eval { require Data::UUID::LibUUID; 1 } };

    my $backend = $have_libuuid ? "LibUUID" : "DataUUID";

    with "MooseX::Storage::Directory::Role::UUIDs::$backend";
}

__PACKAGE__

__END__
