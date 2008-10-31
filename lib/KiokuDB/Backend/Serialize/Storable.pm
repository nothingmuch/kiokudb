#!/usr/bin/perl

package KiokuDB::Backend::Serialize::Storable;
use Moose::Role;

use Storable qw(nfreeze thaw);

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::Serialize
    KiokuDB::Backend::UnicodeSafe
    KiokuDB::Backend::BinarySafe
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

__PACKAGE__

__END__
