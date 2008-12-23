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
