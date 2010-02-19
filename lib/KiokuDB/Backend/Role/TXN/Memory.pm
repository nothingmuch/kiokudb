#!/usr/bin/perl

package KiokuDB::Backend::Role::TXN::Memory;
use Moose::Role;

use Carp qw(croak);

use KiokuDB::Util qw(deprecate);

with qw(KiokuDB::Backend::Role::TXN);

use namespace::clean -except => 'meta';

requires qw(commit_entries get_from_storage);

# extremely slow/shitty fallback method, will be deprecated eventually
sub exists_in_storage {
    my ( $self, @uuids ) = @_;

    deprecate('0.37', 'exists_in_storage should be implemented in TXN::Memory using backends');

    map { $self->get_from_storage($_) ? 1 : '' } @uuids;
}

has _txn_stack => (
    isa => "ArrayRef",
    is  => "ro",
    default => sub { [] },
);

sub _new_frame {
    return {
        'live'     => {},
        'log'      => [],
        'cleared'  => !1,
    };
}

sub txn_begin {
    my $self = shift;

    push @{ $self->_txn_stack }, $self->_new_frame;
}

sub txn_rollback {
    my $self = shift;

    pop @{ $self->_txn_stack } || croak "no open transaction";
}

sub txn_commit {
    my $self = shift;

    my $stack = $self->_txn_stack;

    my $txn = pop @$stack || croak "no open transaction";

    if ( @{ $self->_txn_stack } ) {
        $stack->[-1] = $self->_collapse_txn_frames($txn, $stack->[-1]);
    } else {
        $self->clear_storage if $txn->{cleared};
        $self->commit_entries(@{ $txn->{log} });
    }
}

sub _collapsed_txn_stack {
    my $self = shift;

    $self->_collapse_txn_frames(reverse @{ $self->_txn_stack });
}

sub _collapse_txn_frames {
    my ( $self, $head, @tail ) = @_;

    return $self->_new_frame unless $head;

    return $head unless @tail;

    my $next = shift @tail;

    if ( $head->{cleared} ) {
        return $head;
    } else {
        my $merged = {
            cleared => $next->{cleared},
            log => [
                @{ $next->{log} },
                @{ $head->{log} },
            ],
            live => {
                %{ $next->{live} },
                %{ $head->{live} },
            },
        };

        return $self->_collapse_txn_frames( $merged, @tail );
    }
}

# FIXME remove duplication between get/exists
sub get {
    my ( $self, @uuids ) = @_;

    my %entries;
    my %remaining = map { $_ => undef } @uuids;

    my $stack = $self->_txn_stack;

    foreach my $frame ( @$stack ) {
        # try to find a modified entry for every remaining key
        foreach my $id ( keys %remaining ) {
            if ( my $entry = $frame->{live}{$id} ) {
                if ( $entry->deleted ) {
                    return ();
                }
                $entries{$id} = $entry;
                delete $remaining{$id};
            }
        }

        # if there are no more remaining keys, we can stop examining the
        # transaction frames
        last unless keys %remaining;

        # if the current frame has cleared the DB and there are still remaining
        # keys, they are supposed to fail the lookup
        return () if $frame->{cleared};
    }

    if ( keys %remaining ) {
        my @remaining = $self->get_from_storage(keys %remaining);

        if ( @remaining ) {
            @entries{keys %remaining} = @remaining;
            @{ $stack->[-1]{live} }{keys %remaining} = @remaining if @$stack;
        } else {
            return ();
        }
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
            if ( my $entry = $frame->{live}{$id} ) {
                $exists{$id} = not $entry->deleted;
                delete $remaining{$id};
            }
        }

        last unless keys %remaining;

        if ( $frame->{cleared} ) {
            @exists{keys %remaining} = ('') x keys %remaining;
            return @exists{@uuids};
        }
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
        my $head = $self->_txn_stack->[-1];
        push @{ $head->{log} }, @entries;
        @{$head->{live}}{map { $_->id } @entries} = @entries;
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

Entries with C<deleted> should be removed from the database, entries with a
C<prev> entry should be inserted, and all other entries should be updated.

Multiple entries may be given for a single object, for instance an object that
was first inserted and then modified will have an insert entry and an update
entry.

=item get_from_storage

Should be the same as L<KiokuDB::Backend/get>.

When no memory buffered entries are available for the object one is fetched
from the backend.

=item exists_in_storage

Required as of L<KiokuDB> version 0.37.

A fallback implementation is provided, but should not be used and will issue a
deprecation warning.

=back

=cut

