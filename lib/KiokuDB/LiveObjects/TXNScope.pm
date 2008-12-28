#!/usr/bin/perl

package KiokuDB::LiveObjects::TXNScope;
use Moose;

use namespace::clean -except => 'meta';

has entries => (
    isa => "ArrayRef",
    is  => "ro",
    default => sub { [] },
);

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    required => 1,
);

has parent => (
    isa => __PACKAGE__,
    is  => "ro",
);

sub update_entries {
    my ( $self, @entries ) = @_;
    push @{ $self->entries }, @entries;
}

sub rollback {
    my $self = shift;
    $self->live_objects->rollback_entries(splice @{ $self->entries });
}

sub DEMOLISH {
    my $self = shift;

    if ( my $l = $self->live_objects ) {
        if ( my $parent = $self->parent ) {
            $l->_set_txn_scope($parent);
        } else {
            $l->_clear_txn_scope();
        }
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::LiveObjects::TXNScope - Transaction scope.

=head1 SYNOPSIS

    $txn_scope = $live_objects->new_txn;

    $txn_scope->update_entries(@updated);

    $txn_scope->rollback;

=head1 DESCRIPTION

This is an auxillary class used by transaction scoping to roll back entrries
updated during a transaction when it is aborted.

This is used internally in L<KiokuDB/txn_do> and should not need to be used
directly.

=head1 ATTRIBUTES

=over 4

=item entries

An ordered log of updated entries.

=back

=head1 METHODS

=over 4

=item update_entries

Called by L<KiokuDB::LiveObjects/update_entries>. Adds entries to C<entries>.

=item rollback

Calls C<KiokuDB::LiveObjects/rollback_entries> with all the recorded entries.

=back

=cut


