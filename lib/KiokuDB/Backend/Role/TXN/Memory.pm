#!/usr/bin/perl

package KiokuDB::Backend::Role::TXN::Memory;
use Moose::Role;

use Carp qw(croak);

with qw(KiokuDB::Backend::Role::TXN);

use namespace::clean -except => 'meta';

requires qw(commit_entries get_from_storage);

# extremely slow/shitty fallback method, will be deprecated eventually
sub exists_in_storage {
    my ( $self, @uuids ) = @_;

    map { $self->get_from_storage($_) ? 1 : '' } @uuids;
}

has _txn_stack => (
    isa => "ArrayRef",
    is  => "ro",
    default => sub { [] },
);

sub txn_begin {
    my $self = shift;

    push @{ $self->_txn_stack }, {
        modified => {},
        read => [],
    };
}

sub txn_rollback {
    my $self = shift;

    pop @{ $self->_txn_stack } || croak "no open transaction";
}

sub txn_commit {
    my $self = shift;

    my $txn = pop @{ $self->_txn_stack } || croak "no open transaction";
    my $modified = $txn->{modified};

    if ( @{ $self->_txn_stack } ) {
        my $head = $self->_txn_stack->[-1]{modified};
        @{ $head }{keys %$modified} = values %$modified;
    } else {
        $self->commit_entries(values %$modified);
    }
}

sub txn_loaded_entries {
    my ( $self, @entries ) = @_;

    if ( @{ $self->_txn_stack } ) {
        my $txn = $self->_txn_stack->[-1];
        push @{ $txn->{read} }, @entries;
    }

    @entries;
}

# FIXME remove duplication between get/exists
sub get {
    my ( $self, @uuids ) = @_;

    my %entries;
    my %remaining = map { $_ => undef } @uuids;

    foreach my $frame ( @{ $self->_txn_stack } ) {
        foreach my $id ( keys %remaining ) {
            if ( my $entry = $frame->{modified}{$id} ) {
                if ( $entry->deleted ) {
                    return ();
                }
                $entries{$id} = $entry;
                delete $remaining{$id};
            }
        }

        last unless keys %remaining;
    }

    if ( keys %remaining ) {
        @entries{keys %remaining} = $self->get_from_storage(keys %remaining);
    }

    return @entries{@uuids};
}

# FIXME remove duplication between get/exists
sub exists {
    my ( $self, @uuids ) = @_;

    my %exists;
    my %remaining = map { $_ => undef } @uuids;

    foreach my $frame ( @{ $self->_txn_stack } ) {
        foreach my $id ( keys %remaining ) {
            if ( my $entry = $frame->{modified}{$id} ) {
                $exists{$id} = not $entry->deleted;
                delete $remaining{$id};
            }
        }

        last unless keys %remaining;
    }

    if ( keys %remaining ) {
        @exists{keys %remaining} = $self->exists_in_storage(keys %remaining);
    }

    return @exists{@uuids};
}

sub delete {
    my ( $self, @ids_or_entries ) = @_;

    my @entries = grep { ref } @ids_or_entries;

    my @ids = grep { not ref } @ids_or_entries;

    my @new_entries = map { $_->deletion_entry } $self->get(@ids);

    $self->insert(@entries, @new_entries);

    return @new_entries;
}

sub insert {
    my ( $self, @entries ) = @_;

    if ( @{ $self->_txn_stack } ) {
        my $head = $self->_txn_stack->[-1]{modified};
        @{$head}{map { $_->id } @entries} = @entries;
    } else {
        $self->commit_entries(@entries);
    }
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Role::TXN::Memory - In memory transactions.

=head1 SYNOPSIS

    with qw(KiokuDB::Backend::Role::TXN::Memory);

    sub commit_entries {
        my ( $self, @entries ) = @_;

        # atomically apply @entries

        # deleted entries have the deleted flag set
        # if an entry has no 'prev' entry it's an insert
        # otherwise it's an update
    }

=head1 DESCRIPTION

This backend provides in memory transactions for backends which support atomic
modification of data, but not full commit/rollback support.

This backend works by buffering all operations in memory. Entries are kept
alive allowing read operations go to the live entry even for objects that are
out of scope.

This implementation provides repeatable read level isolation. Durability,
concurrency and atomicity are still the responsibility of the backend.

=head1 REQUIRED METHODS

=over 4

=item commit_entries

Insert, update or delete entries as specified.

This operation should either fail or succeed atomically.

=back

=cut

