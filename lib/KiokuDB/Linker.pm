#!/usr/bin/perl

package KiokuDB::Linker;
use Moose;

use Carp qw(croak);
use Check::ISA;
use Data::Swap qw(swap);

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "rw",
    required => 1,
);

has backend => (
    does => "KiokuDB::Backend",
    is  => "rw",
    required => 1,
);

sub expand_object {
    my ( $self, $entry, %args ) = @_;

    if ( my $class = $entry->class ) {
        my $meta = Class::MOP::get_metaclass_by_name($class);

        my $instance = $meta->get_meta_instance->create_instance();

        # note, this is registered *before* any other value expansion, to allow circular refs
        $self->live_objects->insert( $entry => $instance );

        my $data = $entry->data;

        foreach my $attr ( $meta->compute_all_applicable_attributes ) {
            my $name = $attr->name;
            next unless exists $data->{$name};
            my $value = $data->{$name};
            $attr->set_value( $instance, $self->visit($value) );
        }

        return $instance;
    } else {
        # FIXME remove Data::Swap
        # make sure we have some sort of refaddr in case of circular refs to simple structures
        # after visiting $entry->data we swap it
        # the alternative (no Data::Swap) approach is to register the object by subclassing
        # the visitor such that _register_mapping registers with the live
        # object cache if the refaddr() of the mapping source is equal to refaddr($entry->data)
        my $placeholder = {};
        $self->live_objects->insert( $entry => $placeholder );
        my $data = $self->visit( $entry->data );
        swap($data, $placeholder);
        return $placeholder;
    }
}

sub visit_object {
    my ( $self, $object ) = @_;

    if ( obj $object, "KiokuDB::Reference" ) {
        # FIXME if $object->is_weak then we need a Data::Visitor api to make
        # sure the container this gets put in is weakened
        # not a huge issue because usually we'll encounter attrs with weak_ref
        # => 1, but this is still needed for correctness

        # GAH! just returning the object is broken, gotta find out why
        my $obj = $self->get_or_load_object( $object->id );
        return $obj;
    } else {
        croak "Unexpected object $object in entry";
    }
}

sub get_or_load_objects {
    my ( $self, @ids ) = @_;

    map { $self->get_or_load_object($_) } @ids;
}

sub get_or_load_object {
    my ( $self, $id ) = @_;

    if ( defined( my $obj = $self->live_objects->id_to_object($id) ) ) {
        return $obj;
    } else {
        $self->load_object($id);
    }
}

sub load_object {
    my ( $self, $id, @args ) = @_;
    if ( my $entry = $self->backend->get($id) ) {
        $self->expand_object( $entry, @args );
    } else {
        die { missing => $id };
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Linker - Relinks live objects from storage entries

=head1 SYNOPSIS

=head1 DESCRIPTION

This object reconnects and blesses entry data using the MOP to recreate the
connected graph in memory.

If a live object already exists for a UID then that object will be reused.

=head1 TODO

=over 4

=item *

Ultra-sleazy L<Data::Thunk> based lazy loading of references

=back

=cut


