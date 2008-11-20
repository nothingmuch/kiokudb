#!/usr/bin/perl

package KiokuDB::LinkChecker;
use Moose;

use Set::Object;

use namespace::clean -except => 'meta';

has entries => (
    does => "Data::Stream::Bulk",
    is   => "ro",
    required => 1,
);

# Set::Object of 1 million IDs is roughly 100mb of memory == 100 bytes per ID
# no need to scale anything more, if you have that many objects you should
# probably write your own tool
has [qw(seen referenced missing)] => (
    isa => "Set::Object",
    is  => "ro",
    lazy_build => 1,
);

sub _build_missing {
    my $self = shift;

    $self->referenced->difference( $self->seen );
}

sub missing_ids {
    my $self = shift;
    $self->missing->members;
}

sub _build_seen {
    my $self = shift;

    my ( $seen, $referenced ) = $self->_visit_entries;

    $self->meta->find_attribute_by_name("referenced")->set_value( $self, $referenced );

    return $seen;
}

sub _build_referenced {
    my $self = shift;

    my ( $seen, $referenced ) = $self->_visit_entries;

    $self->meta->find_attribute_by_name("seen")->set_value( $self, $seen );

    return $referenced;
}

sub _visit_entries {
    my $self = shift;

    my ( $seen, $referenced ) = map { Set::Object->new } 1 .. 2;

    while ( my $next = $self->entries->next ) {
        foreach my $entry ( @$next ) {
            # FIXME progress report?
            $seen->insert($entry->id);

            my @ids = $entry->referenced_ids;

            $referenced->insert(@ids);

            # incremental pass requires backend... implement?

            #my @new_ids = grep { !$seen->includes($_) && !$missing->includes($_) } @ids;

            #my %exists; @exists{@new_ids} = $self->backend->exists(@new_ids);

            #foreach my $id ( @new_ids ) {
            #    ( $exists{$id} ? $seen : $missing )->insert($id);
            #}

        }
    }

    return ( $seen, $referenced );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::LinkChecker - 

=head1 SYNOPSIS

	use KiokuDB::LinkChecker;

=head1 DESCRIPTION

=cut


