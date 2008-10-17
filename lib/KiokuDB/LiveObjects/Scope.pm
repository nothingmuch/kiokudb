#!/usr/bin/perl

package KiokuDB::LiveObjects::Scope;
use Moose;

use namespace::clean -except => 'meta';

has objects => (
    isa => "ArrayRef",
    is  => "ro",
    default => sub { [] },
);

sub push {
    my ( $self, @objs ) = @_;
    push @{ $self->objects }, @objs;
}

sub clear {
    my $self = shift;
    @{ $self->objects } = ();
}

has parent => (
    isa => __PACKAGE__,
    is  => "ro",
);

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    required => 1,
);

sub DEMOLISH {
    my $self = shift;

    # consider possibilities of optimizing live object set removal at this
    # point

    # problems can arise from an object outliving the scope it was loaded in:
    # { my $outer = lookup(...); { my $inner = lookup(...); $outer->foo($inner) } }

    if ( my $l = $self->live_objects ) {
        if ( my $parent = $self->parent ) {
            $l->_set_current_scope($parent);
        } else {
            $l->_clear_current_scope();
        }
    }

    # FIXME in debug mode detect if @{ $self->objects } = (), but said objects
    # survive the cleanup and warn about them
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

=back

=cut


