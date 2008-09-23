#!/usr/bin/perl

package KiokuDB::Backend::BDB::GIN;
use Moose;

use Data::Stream::Bulk::Util qw(cat);

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Backend::BDB);

with qw(
    KiokuDB::Backend::Query::GIN
    Search::GIN::Extract::Delegate
);

sub BUILD { shift->secondary_db } # early

has secondary_db => (
    is => "ro",
    lazy_build => 1,
);

sub _build_secondary_db {
    my $self = shift;
    $self->_open_secondary( name => "secondary", file => "gin_index" );
}

has root_only => (
    isa => "Bool",
    is  => "ro",
    default => 1,
);

sub _open_secondary {
    my ( $self, @args ) = @_;

    my $secondary = $self->manager->open_db( dup => 1, dupsort => 1, @args );

    $self->manager->associate(
        secondary => $secondary,
        primary   => $self->primary_db,
        callback  => sub {
            my ( $id, $blob ) = @_;

            my $entry = $self->deserialize($blob);

            my $b = $entry->backend_data || return [];

            return $b->{keys} || [];
        },
    );

    return $secondary;
}


before insert => sub {
    my ( $self, @entries ) = @_;

    foreach my $entry ( @entries ) {
        if ( $entry->deleted || !$entry->has_object || ( !$entry->root && $self->root_only ) ) {
            $entry->clear_backend_data;
        } else {
            my $d = $entry->backend_data || $entry->backend_data({});
            $d->{keys} = [ $self->extract_values( $entry->object, entry => $entry ) ];
        }
    }
};

sub search {
    my ( $self, $query, @args ) = @_;

    my %args = (
        distinct => $self->distinct,
        @args,
    );

    my %spec = $query->extract_values($self);

    my @streams;

    # FIXME avoid loading/deserializing entries which are already in the live entry set
    # Query::GIN should filter based on live objects before calling ->get
    # also, consider opening the secondary db non associated to get the ids,
    # instead of the entries
    foreach my $key ( @{ $spec{values} } ) {
        my $matches = $self->manager->dup_cursor_stream(
            db     => $self->secondary_db,
            values => 1,
            key    => $key,
        );

        push @streams, $matches->filter(sub {[ map { $self->deserialize($_) } @$_ ]});
    }

    return cat(@streams);
}

sub fetch_entry { die "TODO" }

sub remove_ids {
    my ( $self, @ids ) = @_;

    die "Deletion the GIN index is handled implicitly by BDB";
}

sub insert_entry {
    my ( $self, $id, @keys ) = @_;

    die "Insertion to the GIN index is handled implicitly by BDB";
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::BDB::GIN - 

=head1 SYNOPSIS

	use KiokuDB::Backend::BDB::GIN;

=head1 DESCRIPTION

=cut


