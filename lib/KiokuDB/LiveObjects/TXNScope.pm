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

KiokuDB::LiveObjects::TXNScope - 

=head1 SYNOPSIS

	use KiokuDB::LiveObjects::TXNScope;

=head1 DESCRIPTION

=cut


