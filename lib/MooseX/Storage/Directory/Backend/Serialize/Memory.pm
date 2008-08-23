#!/usr/bin/perl

package MooseX::Storage::Directory::Backend::Serialize::Memory;
use Moose::Role;

use Storable qw(dclone);

use namespace::clean -except => 'meta';

sub serialize {
    my ( $self, $entry ) = @_;

    return dclone($entry);
}

sub deserialize {
    my ( $self, $blob ) = @_;

    return defined($blob) && dclone($blob);
}

__PACKAGE__

__END__
