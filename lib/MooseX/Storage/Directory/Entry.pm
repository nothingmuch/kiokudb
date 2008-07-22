#!/usr/bin/perl

package MooseX::Storage::Directory::Entry;
use Moose;

has id => (
    isa => "Str",
    is  => "rw",
);

has root => (
    isa => "Bool",
    is  => "rw",
);

has data => (
    isa => "Ref",
    is  => "rw",
);

has class => (
    isa => "Class::MOP::Class",
    is  => "rw",
    predicate => "has_class",
);

sub STORABLE_freeze {
    my ( $self, $cloning ) = @_;

    return (
        join(",",
            $self->id,
            !!$self->root,
            $self->has_class ? $self->class->identifier : '',
        ),
        $self->data,
    );
}

sub STORABLE_thaw {
    my ( $self, $cloning, $attrs, $data ) = @_;
    
    my ( $id, $root, $class ) = split ',', $attrs;

    $self->id($id);
    $self->root(1) if $root;;
    $self->class( $class->meta ) if $class; # FIXME
    $self->data($data);

    return $self;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::Storage::Directory::Entry - An entry in the database

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
using a L<MooseX::Storage::Directory::Reference> object with UIDs as the
address space.

=item class

If the entry is an object this contains the metaclass of that object.

=back

=head1 TODO

=over 4

=item *

Model tiedness as a specialization of class?

=back

=cut
