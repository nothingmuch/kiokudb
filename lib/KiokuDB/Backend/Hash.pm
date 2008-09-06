#!/usr/bin/perl

package KiokuDB::Backend::Hash;
use Moose;

use Data::Stream::Bulk::Util qw(bulk);

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::Serialize::Memory
    KiokuDB::Backend
    KiokuDB::Backend::Query::Simple
    KiokuDB::Backend::Scan
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
    my ( $self, @ids_or_entries ) = @_;

    my @uids = map { ref($_) ? $_->id : $_ } @ids_or_entries;

    delete @{ $self->storage }{@uids};
}

sub exists {
    my ( $self, @uids ) = @_;

    map { exists $self->storage->{$_} } @uids;
}

sub scan {
    my $self = shift;

    my @ret;

    foreach my $entry ( values %{ $self->storage } ) {
        push @ret, $self->deserialize($entry) if $entry->root;
    }

    return bulk(@ret);
}

sub simple_search {
    my ( $self, $proto ) = @_;

    # FIXME $proto is sql::abstract 2? or...?

    my $root_set = $self->scan;

    return $root_set->filter(sub {
        return [ grep {
            my $entry = $_;
            $self->compare_naive($entry->data, $proto);
        } @$_ ]
    });
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
