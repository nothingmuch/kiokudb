#!/usr/bin/perl

package MooseX::Storage::Directory::Collapser;
use Moose;

use Carp qw(croak);
use Data::Swap qw(swap);
use Scalar::Util qw(isweak);

use MooseX::Storage::Directory::Entry;
use MooseX::Storage::Directory::Reference;

use Data::Visitor 0.18;

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

has resolver => (
    isa => "MooseX::Storage::Directory::Resolver",
    is  => "rw",
    required => 1,
    handles => [qw(objects_to_ids object_to_id)],
);

has '+weaken' => (
    default => 0,
);

has _accum_uids => (
    isa => 'HashRef',
    is  => "rw",
    default => sub { +{} },
);

sub collapse_objects {
    my ( $self, @objects ) = @_;

    local %{ $self->_accum_uids } = ();

    my @ids = $self->objects_to_ids(@objects);

    $self->visit(\@objects);

    my @root_set = delete @{ $self->_accum_uids }{@ids};

    $_->root(1) for @root_set;

    return ( @root_set, values %{ $self->_accum_uids } );
}

sub visit_seen {
    my ( $self, $seen, $prev ) = @_;

    my $id = $self->object_to_id($seen);

    unless ( exists $self->_accum_uids->{$id} ) {
        my $ref = MooseX::Storage::Directory::Reference->new( id => $id ); # not weak, this was handled by visit_ref

        # inject the reference into the data structure where it was first seen
        swap( $ref, $prev );

        $self->_accum_uids->{$id} = MooseX::Storage::Directory::Entry->new(
            id   => $id,
            data => $ref, # not the ref, but actually what $prev was
        );

    }

    return MooseX::Storage::Directory::Reference->new( id => $id, isweak($_[1]) ? ( is_weak => 1 ) : () );
}

sub visit_ref {
    my ( $self, $ref ) = @_;

    if ( isweak($_[1]) ) {
        # weak references get an entry so that they are garbage collecte
        my $id = $self->object_to_id($ref);

        $self->_accum_uids->{$id} = MooseX::Storage::Directory::Entry->new(
            id   => $id,
            data => $self->SUPER::visit_ref($ref),
        );

        return MooseX::Storage::Directory::Reference->new( id => $id, is_weak => 1 );
    } else {
        return $self->SUPER::visit_ref($ref);
    }
}

sub visit_object {
    my ( $self, $object ) = @_;

    if ( $object->can("meta") ) {
        my $id = $self->object_to_id($object);

        my $ref = MooseX::Storage::Directory::Reference->new( id => $id, isweak($_[1]) ? ( is_weak => 1 ) : () );

        # Data::Visitor stuff for circular refs
        $self->_register_mapping( $object, $ref );

        my $meta = $object->meta;

        my @attrs = $meta->compute_all_applicable_attributes;

        my $hash = {
            map {
                my $attr = $_;
                # FIXME readd MooseX::Storage::Engine type mappings here
                # need to refactor Engine, or go back to subclassing it
                my $value = $attr->get_value($object);
                my $collapsed = $self->visit($value);
                ( $attr->name => $collapsed );
            } @attrs
        };

        $self->_accum_uids->{$id} = MooseX::Storage::Directory::Entry->new(
            data  => $hash,
            id    => $id,
            class => $meta,
        );

        return $ref;
    } else {
        croak "FIXME non moose objects";
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::Storage::Directory::Collapser - Collapse object hierarchies to entry
data

=head1 SYNOPSIS

=head1 DESCRIPTION

This object walks object structures using L<Data::Visitor> and produces
simple standalone entries (no shared data, no circular references, no blessed
structures) with symbolic (UUID based) links.

=head1 TODO

=over 4

=item *

Tied data

=item *

Custom hooks

=item *

Non moose objects

(Adapt L<Storable> hooks, L<Pixie::Complicity>, etc etc)

=back

=cut

