#!/usr/bin/perl

package KiokuDB::Entry;
use Moose;

use Moose::Util::TypeConstraints;

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

my %tied = (
    "H" => "HASH",
    "S" => "SCALAR",
    "A" => "ARRAY",
    "G" => "GLOB",
);

my %tied_r = reverse %tied;

has tied => (
    isa => enum([ values %tied ]),
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

    KiokuDB::Entry->new(
        id => ...,
        data => ...
    );

=head1 DESCRIPTION

This object provides the meta data for a single storage entry.

=head1 ATTRIBUTES

=over 4

=item id

The UUID for the entry.

If there is no ID then the entry is intrinsic.

=item root

Whether or not this is a member of the root set (not subject to garbage
collection, because storage was explicitly requested).

=item data

A simplified data structure modeling this object/reference. This is a tree, not
a graph, and has no shared data (JSON compliant). All references are symbolic,
using a L<KiokuDB::Reference> object with UIDs as the
address space.

=item class

If the entry is blessed, this contains the class of that object.

In the future this might be a complex structure for anonymous classes, e.g. the
class and the runtime roles.

=item tied

One of C<HASH>, C<ARRAY>, C<SCALAR> or C<GLOB>.

C<data> is assumed to be a reference or an intrinsic entry for the object
driving the tied structure (e.g. the C<tied(%hash)>).

=item prev

Contains a link to a L<KiokuDB::Entry> objects that precedes this one.

The last entry that was loaded from the store, or successfully written to the
store for a given UUID is kept in the live object set.

The collapser creates transient Entry objects, which if written to the store
successfully are replace the previous one.

=item backend_data

Backends can use this to store additional meta data as they see fit.

For instance, this is used in the CouchDB backend to track entry revisions for
the opportunistic locking, and in L<KiokuDB::Backend::BDB::GIN> to to store
extracted keys.

=back

=cut
