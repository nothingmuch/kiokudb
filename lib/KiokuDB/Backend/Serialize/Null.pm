#!/usr/bin/perl

package KiokuDB::Backend::Serialize::Null;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::Serialize
    KiokuDB::Backend::UnicodeSafe
    KiokuDB::Backend::BinarySafe
);

sub serialize {
    my ( $self, $entry ) = @_;

    return $entry;;
}

sub deserialize {
    my ( $self, $entry ) = @_;

    return $entry;
}


__PACKAGE__

__END__
