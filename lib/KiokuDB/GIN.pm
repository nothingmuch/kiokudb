#!/usr/bin/perl

package KiokuDB::GIN;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(
    Search::GIN::Driver
    Search::GIN::Extract
    KiokuDB::Backend
    KiokuDB::Backend::Query
);

has backend => (
    does => "KiokuDB::Backend",
    is   => "ro",
    required => 1,
    # handles => [qw(get exists)],
);

has root_only => (
    isa => "Bool",
    is  => "ro",
    default => 1,
);

sub exists { shift->backend->exist(@_) }
sub get { shift->backend->exist(@_) }

sub insert {
    my ( $self, @entries ) = @_;

    $self->backend->insert(@entries);

    my @idx_entries = grep { $_->has_object } @entries;

    foreach my $entry ( @idx_entries ) {
        my @keys = $self->extract_values( $entry->object );
        $self->insert_entry( $entry->id, @keys );
    }
}

sub delete {
    my ( $self, @ids_or_entries ) = @_;

    $self->backend->delete(@ids_or_entries);

    my @ids = map { ref($_) ? $_->id : $_ } @ids_or_entries;

    $self->remove_ids(@ids);
}

has distinct => (
    isa => "Bool",
    is  => "rw",
    default => 0, # FIXME what should the default be?
);

sub search {
    my ( $self, $query, @args ) = @_;

    my %args = (
        distinct => $self->distinct,
        @args,
    );

    my @spec = $query->extract_values;

    my $ids = $self->fetch_entries(@spec);

    $ids = unique($ids) if $args{distinct};

    return $ids->filter(sub {[ $self->backend->get(@$_) ]});
}

sub search_filter {
    my ( $self, $objects, $query, @args ) = @_;
    return $objects->filter(sub { [ grep { $query->consistent($self, $_) } @$_ ] });
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::GIN - Gin assisted recollection

=head1 SYNOPSIS

	use KiokuDB::GIN;

=head1 DESCRIPTION



=cut


