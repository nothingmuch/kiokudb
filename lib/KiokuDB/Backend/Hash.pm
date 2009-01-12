#!/usr/bin/perl

package KiokuDB::Backend::Hash;
use Moose;

use Data::Stream::Bulk::Util qw(bulk);

use Carp qw(croak);

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::Serialize::Delegate
    KiokuDB::Backend
    KiokuDB::Backend::Role::Query::Simple::Linear
    KiokuDB::Backend::Role::Scan
    KiokuDB::Backend::Role::Clear
);

has storage => (
    isa => "HashRef",
    is  => "rw",
    default => sub { {} },
);

sub clear {
    my $self = shift;
    %{ $self->storage } = ();
}

sub get {
    my ( $self, @uids ) = @_;

    my $s = $self->storage;

    return if grep { not exists $s->{$_} } @uids;

    my @objs = map { $self->deserialize($_) } @{ $s }{@uids};

    if ( @objs == 1 ) {
        return $objs[0];
    } else {
        return @objs;
    }
}

sub insert {
    my ( $self, @entries ) = @_;

    my $s = $self->storage;

    foreach my $entry ( @entries ) {
        next if $entry->has_prev;
        my $id = $entry->id;
        croak "Entry $id already exists in the database" if exists $s->{$id};
    }

    @{ $s }{ map { $_->id } @entries } = map { $self->serialize($_) } @entries;
}

sub delete {
    my ( $self, @ids_or_entries ) = @_;

    my @uids = map { ref($_) ? $_->id : $_ } @ids_or_entries;

    delete @{ $self->storage }{@uids};
}

sub exists {
    my ( $self, @uids ) = @_;

    map { exists $self->storage->{$_} } @uids;
}

sub all_entries {
    my $self = shift;
    return bulk(map { $self->deserialize($_) } values %{ $self->storage });
}

sub all_entry_ids {
    my $self = shift;
    return bulk(keys %{ $self->storage });
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
L<KiokuDB::Entry> objects using L<Storable>'s C<dclone> to make dumps of the
backend clear.

=cut
