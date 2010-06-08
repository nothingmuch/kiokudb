#!/usr/bin/perl

package KiokuDB::LiveObjects::Scope;
use Moose;

use namespace::clean -except => 'meta';

has objects => (
    traits => [qw(Array)],
    isa => "ArrayRef",
    default => sub { [] },
    clearer => "_clear_objects",
    handles => {
        push => "push",
        objects => "elements",
        clear => "clear",
    },
);

has parent => (
    isa => __PACKAGE__,
    is  => "ro",
);

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    clearer => "_clear_live_objects",
);

sub DEMOLISH {
    my $self = shift;

    # consider possibilities of optimizing live object set removal at this
    # point

    # problems can arise from an object outliving the scope it was loaded in:
    # { my $outer = lookup(...); { my $inner = lookup(...); $outer->foo($inner) } }

    $self->remove;
}

sub detach {
    my $self = shift;

    if ( my $l = $self->live_objects ) {
        $l->detach_scope($self);
    }
}

sub remove {
    my $self = shift;

    if ( my $l = $self->live_objects ) { # can be false under global destruction
        $l->remove_scope($self);
        $self->_clear_live_objects;
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::LiveObjects::Scope - Scope helper object

=head1 SYNOPSIS

    {
        my $scope = $dir->new_scope;

        ... do work on $dir ...
    }

=head1 DESCRIPTION

Live object scopes exist in order to ensure objects don't die too soon if the
only other references to them are weak.

When scopes are destroyed the refcounts of the objects they refer to go down,
and the parent scope is replaced in the live object set.

=head1 METHODS

=over 4

=item push

Adds objects or entries, increasing their reference count.

=item clear

Clears the objects from the scope object.

=item detach

Marks this scope as no longer the "current" live object scope, if it is the current one.

This allows keeping branching of scopes, which can be useful under long running
applications.

=item remove

Effectively kills the scope by clearing it and removing it from the live object set.

=back

=cut


