#!/usr/bin/perl

package MooseX::Storage::Directory::Backend::Serialize::Storable;
use Moose::Role;

use Storable qw(nfreeze thaw);

use namespace::clean -except => 'meta';

with qw(MooseX::Storage::Directory::Backend::Serialize);

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
