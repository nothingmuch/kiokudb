#!/usr/bin/perl

package KiokuDB::GIN;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::Query::GIN
    Search::GIN::Driver
);

has root_only => (
    isa => "Bool",
    is  => "ro",
    default => 1,
);

after insert => sub {
    my ( $self, @entries ) = @_;

    @entries = grep { $_->root } @entries if $self->root_only;

    my @idx_entries = grep { $_->has_object } @entries;

    foreach my $entry ( @idx_entries ) {
        my @keys = $self->extract_values( $entry->object );
        $self->insert_entry( $entry->id, @keys );
    }
};

after delete => sub {
    my ( $self, @ids_or_entries ) = @_;

    my @ids = map { ref($_) ? $_->id : $_ } @ids_or_entries;

    $self->remove_ids(@ids);
};

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::GIN - Gin assisted recollection

=head1 SYNOPSIS

	use KiokuDB::GIN;

=head1 DESCRIPTION



=cut


