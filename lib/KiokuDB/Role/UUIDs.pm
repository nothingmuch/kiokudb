#!/usr/bin/perl

package KiokuDB::Role::UUIDs;
use Moose::Role;

use namespace::clean -except => 'meta';

if ( defined &KiokuDB::SERIAL_IDS and KiokuDB::SERIAL_IDS() ) {
    with qw(KiokuDB::Role::UUIDs::SerialIDs);
} else {
    my $have_libuuid = do { local $@; eval { require Data::UUID::LibUUID; 1 } };

    my $backend = $have_libuuid ? "LibUUID" : "DataUUID";

    with "KiokuDB::Role::UUIDs::$backend";
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Role::UUIDs - UUID generation role.

=head1 SYNOPSIS

    with qw(KiokuDB::Role::UUIDs);

=head1 DESCRIPTION

This role provides UUID assignment.

Depending on the C<$SERIAL_IDS> variable being true at compile time, and
availability of UUID generation module (L<Data::UUID::LibUUID> falling back to
L<Data::UUID>) an implementation role is selected.

=head1 METHODS

=over 4

=item generate_uuid

Create a new UUID

=item uuid_to_string

=item string_to_uuid

Conversion subroutines for completeness.

=back

=cut
