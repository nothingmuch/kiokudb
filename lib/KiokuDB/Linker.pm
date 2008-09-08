#!/usr/bin/perl

package KiokuDB::Linker;
use Moose;

# perf improvements:
# use a queue of required objects, queue up references, and bulk fetch
# bulk fetch arrays
# could support a Backend::Queueing which allows queuing of IDs for fetching,
# to help clump or start a request and only read it when it's actually needed


use Carp qw(croak);
use Data::Swap qw(swap);

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    required => 1,
);

has backend => (
    does => "KiokuDB::Backend",
    is  => "ro",
    required => 1,
);

has live_object_cache => (
    isa => "KiokuDB::LiveObjects::Cache",
    is  => "rw",
    clearer => "clear_live_object_cache",
);

sub register_object {
    my ( $self, $entry, $object ) = @_;

    $self->live_objects->insert( $entry => $object );

    if ( my $live_object_cache = $self->live_object_cache ) {
        $live_object_cache->insert( $entry => $object );
    }
}

sub expand_objects {
    my ( $self, @entries ) = @_;

    my $l = $self->live_objects;

    my @objects;

    foreach my $entry ( @entries ) {
        # if the object was referred to in some other entry in @entries, it may
        # have already been loaded.
        if ( defined ( my $obj = $l->id_to_object($entry->id) ) ) {
            push @objects, $obj;
        } else {
            push @objects, $self->expand_object($entry);
        }
    }

    return @objects;
}

sub expand_object {
    my ( $self, $entry ) = @_;

    #confess($entry) unless blessed($entry);

    if ( my $class = $entry->class ) {
        # FIXME fix thawing for alternatively mapped classes
        # (px_thaw, naive, etc)

        my $meta = Class::MOP::get_metaclass_by_name($class);

        my $instance = $meta->get_meta_instance->create_instance();

        # note, this is registered *before* any other value expansion, to allow circular refs
        $self->register_object( $entry => $instance );

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

        # for simple structures with circular refs we need to have the UUID
        # already pointing to a refaddr

        # a better way to do this is to hijack _register_mapping so that when
        # it maps from $entry->data to the new value, we register that with the live object set

        my $placeholder = {};
        $self->register_object( $entry => $placeholder );
        my $data = $self->visit( $entry->data );
        swap($data, $placeholder);
        return $placeholder;
    }
}

sub visit_object {
    my ( $self, $object ) = @_;

    if ( $object->isa("KiokuDB::Reference") ) {
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

    return $self->get_or_load_object($ids[0]) if @ids == 1;

    my %objects;
    @objects{@ids} = $self->live_objects->ids_to_objects(@ids);

    my @missing = grep { not defined $objects{$_} } @ids;

    @objects{@missing} = $self->load_objects(@missing);

    return @objects{@ids};
}

sub load_objects {
    my ( $self, @ids ) = @_;

    my %entries;
    @entries{@ids} = $self->live_objects->ids_to_entries(@ids);

    if ( my @load = grep { !$entries{$_} } @ids ) {
        #confess if @load == 1;
        @entries{@load} = $self->backend->get(@load);

        if ( my @missing = grep { !$entries{$_} } @load ) {
            die { missing => \@missing };
        }

        $self->live_objects->insert_entries( @entries{@load} );
    }

    return $self->expand_objects( @entries{@ids} );
}

sub get_or_load_object {
    my ( $self, $id ) = @_;

    if ( defined( my $obj = $self->live_objects->id_to_object($id) ) ) {
        return $obj;
    } else {
        return $self->load_object($id);
    }
}

sub load_object {
    my ( $self, $id ) = @_;

    my ( $entry ) = $self->live_objects->ids_to_entries($id);

    unless ( $entry ) {
        $entry = ( $self->backend->get($id) )[0] || die { missing => [ $id ] };
        $self->live_objects->insert_entries($entry );
    }

    $self->expand_object($entry);
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Linker - Relinks live objects from storage entries

=head1 SYNOPSIS

=head1 DESCRIPTION

This object reconnects entry data using the MOP, constructing the connected
object graph in memory.

If a live object already exists for a UID then that object will be reused
instead of being loaded a second time.

=cut


