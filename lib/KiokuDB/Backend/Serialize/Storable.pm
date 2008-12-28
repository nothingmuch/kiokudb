#!/usr/bin/perl

package KiokuDB::Backend::Serialize::Storable;
use Moose::Role;

use Storable qw(nfreeze thaw nstore_fd fd_retrieve);

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::Serialize
    KiokuDB::Backend::Role::UnicodeSafe
    KiokuDB::Backend::Role::BinarySafe
    KiokuDB::Backend::TypeMap::Default::Storable
);

sub serialize {
    my ( $self, $entry ) = @_;

    return nfreeze($entry);
}

sub deserialize {
    my ( $self, $blob ) = @_;

    return thaw($blob);
}

sub serialize_to_stream {
    my ( $self, $fh, $entry ) = @_;
    nstore_fd($entry, $fh);
}

sub deserialize_from_stream {
    my ( $self, $fh ) = @_;

    if ( $fh->eof ) {
        return;
    } else {
        return fd_retrieve($fh);
    }
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Serialize::Storable - L<Storable> based serialization of
L<KiokuDB::Entry> objects.

=head1 SYNOPSIS

    package MyBackend;

    with qw(KiokuDB::Backend::Serialize::Storable;

=head1 DESCRIPTION

This role provides L<Storable> based serialization of L<KiokuDB::Entry> objects
for a backend, with streaming capabilities.

L<KiokuDB::Backend::Serialize::Delegate> is preferred to using this directly.

=head1 METHODS

=over 4

=item serialize $entry

Uses L<Storable/nstore>

=item deserialize $blob

Uses L<Storable/thaw>

=item serialize_to_stream $fh, $entry

Uses L<Storable/nstore_fd>.

=item deserialize_from_stream $fh

Uses L<Storable/fd_retrieve>.

=back
