#!/usr/bin/perl

package MooseX::Storage::Directory::Backend::Hash;
use Moose;

use namespace::clean -except => 'meta';

with qw(
    MooseX::Storage::Directory::Backend::Serialize::Memory
    MooseX::Storage::Directory::Backend
);

has storage => (
    isa => "HashRef",
    is  => "rw",
    default => sub { {} },
);

sub get {
    my ( $self, @uids ) = @_;

    my @objs = map { $self->deserialize($_) } @{ $self->storage }{@uids};

    if ( @objs == 1 ) {
        return $objs[0];
    } else {
        return @objs;
    }
}

sub insert {
    my ( $self, @entries ) = @_;

    @{ $self->storage }{ map { $_->id } @entries } = map { $self->serialize($_) } @entries;
}

sub delete {
    my ( $self, @uids ) = @_;

    delete @{ $self->storage }{@uids};
}

sub exists {
    my ( $self, @uids ) = @_;

    map { exists $self->storage->{$_} } @uids;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
