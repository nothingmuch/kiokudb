#!/usr/bin/perl

package KiokuDB::Entry;
use Moose;

use namespace::clean -except => 'meta';

has id => (
    isa => "Str",
    is  => "rw",
    clearer => "clear_id",
);

has root => (
    isa => "Bool",
    is  => "rw",
);

has deleted => (
    isa => "Bool",
    is  => "rw",
);

has data => (
    isa => "Ref",
    is  => "rw",
    predicate => "has_data",
);

has class => (
    isa => "Str",
    is  => "rw",
    predicate => "has_class",
);

has tied => (
    isa => "Str",
    is  => "rw",
    predicate => "has_tied",
);

has backend_data => (
    isa => "Ref",
    is  => "rw",
    predicate => "has_backend_data",
    clearer   => "clear_backend_data",
);

has prev => (
    isa => __PACKAGE__,
    is  => "rw",
    predicate => "has_prev",
);

has object => (
    isa => "Any",
    is  => "rw",
    weak_ref => 1,
    predicate => "has_object",
);

sub deletion_entry {
    my $self = shift;

    ( ref $self )->new(
        id   => $self->id,
        prev => $self,
        deleted => 1,
        ( $self->has_object       ? ( object       => $self->object       ) : () ),
        ( $self->has_backend_data ? ( backend_data => $self->backend_data ) : () ),
    );
}

my %tied = (
    "H" => "HASH",
    "S" => "SCALAR",
    "A" => "ARRAY",
    "G" => "GLOB",
);

my %tied_r = reverse %tied;

sub STORABLE_freeze {
    my ( $self, $cloning ) = @_;

    no warnings 'uninitialized';
    return (
        join(",",
            $self->id,
            !!$self->root,
            $self->class,
            $tied_r{$self->tied},
            !!$self->deleted,
        ),
        [
            ( $self->has_data         ? $self->data         : undef ),
            ( $self->has_backend_data ? $self->backend_data : undef ),
        ],
    );
}

sub STORABLE_thaw {
    my ( $self, $cloning, $attrs, $refs ) = @_;

    my ( $id, $root, $class, $tied, $deleted ) = split ',', $attrs;

    $self->id($id) if $id;
    $self->root(1) if $root;;
    $self->class($class) if $class;
    $self->tied($tied{$tied}) if $tied;
    $self->deleted(1) if $deleted;

    if ( $refs ) {
        my ( $data, $backend_data ) = @$refs;
        $self->data($data) if ref $data;
        $self->backend_data($backend_data) if ref $backend_data;
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Entry - An entry in the database

=head1 SYNOPSIS

=head1 DESCRIPTION

This object provides the meta data for a single storage entry.

=head1 ATTRIBUTES

=over 4

=item id

The UUID for the netry

=item root

Whether or not this is a member of the root set (not subject to garbage
collection, because storage was explicitly requested).

=item data

A simplified data structure modeling this object/reference. This is a tree, not
a graph, and has no shared data (JSON compliant). All references are symbolic,
using a L<KiokuDB::Reference> object with UIDs as the
address space.

=item class

If the entry is an object this contains the metaclass of that object.

=item prev

Contains a link to a L<KiokuDB::Entry> objects that precedes this one.

The last entry that was loaded from the store, or successfully written to the
store for a given UUID is kept in the live object set.

The collapser creates transient Entry objects, which if written to the store
successfully are replace the previous one.

=item backend_data

Backends can use this to store additional meta data as they see fit.

=back

=head1 TODO

=over 4

=item *

Model tiedness as a specialization of class?

=back

=cut
