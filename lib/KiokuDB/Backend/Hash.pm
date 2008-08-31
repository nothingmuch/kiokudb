#!/usr/bin/perl

package KiokuDB::Backend::Hash;
use Moose;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::Serialize::Memory
    KiokuDB::Backend
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

=pod

=head1 NAME

KiokuDB::Backend::Hash - In memory backend for testing purposes.

=head1 SYNOPSIS

    my $dir = KiokuDB->new(
        backend => KiokuDB::Backend::Hash->new(),
    );

=head1 DESCRIPTION

This L<KiokuDB> backend provides in memory storage and retrieval of
L<KiokuDB::Enty> objects using L<Storable>'s C<dclone> to make dumps of the
backend clear.

=cut
