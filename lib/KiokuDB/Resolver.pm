#!/usr/bin/perl

package KiokuDB::Resolver;
use Moose;

use KiokuDB::LiveObjects;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Role::UUIDs);

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    required => 1,
    handles  => [qw(ids_to_objects id_to_object remove insert)],
);

# get the ID of an object, or make one
sub get_object_id {
    my ( $self, $object ) = @_;

    # FIXME Objects of this sort will probably do their own pre-resolution,
    # with an KiokuDB instance belonging to the metaclass. I don't think we can do
    # any of this yet, and that it will emerge from the first real moose poop
    # impl.

    #if ( blessed($object) and $object->can("does") and $object->does("KiokuDB::UID") ) {
    #    return $object->storage_uid;
    #} else {
    return $self->generate_uuid;
    #}
}

sub object_to_id {
    my ( $self, $obj ) = @_;
    scalar $self->objects_to_ids($obj);
}

sub objects_to_ids {
    my ( $self, @objects ) = @_;

    my @ids;

    my $l = $self->live_objects;

    my %new;

    foreach my $obj ( @objects ) {
        my $id;

        unless ( $id = $l->object_to_id($obj) ) {
            $id = $self->get_object_id($obj);
            $new{$id} = $obj;
        }

        push @ids, $id;
    }

    if ( keys %new ) {
        $self->register_new_ids( %new );
    }

    if ( @objects == 1 ) {
        return $ids[0]; # DWIM in scalar context
    } else {
        return @ids;
    }
}

sub register_new_ids {
    my ( $self, @pairs ) = @_;
    $self->insert( @pairs );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Resolver - Assigns UIDs as necessary to objects

=head1 SYNOPSIS

    use KiokuDB::Resolver;

    my $r = KiokuDB::Resolver->new(
        live_objects => $live_objects,
    );

    my $id = $r->object_to_id($object);

=head1 DESCRIPTION

This object wraps the live object set but also handles UID extraction and
generation.

This is used during collapsing in order to provide IDs for unencountered
objects.

This class may be superseded by the typemap in the future.

=head1 ATTRIBUTES

=over 4

=item live_objects

The underlying live object set.

=back

=head1 METHODS

=over 4

=item get_object_id $object

Generates an ID for an object automatically.

=item object_to_id $object

=item objects_to_ids @objects

Returns or assigns IDS to the given objects.

=item register_new_ids

Delegates to C<insert>. Called by C<objects_to_ids> when new IDs have been
generated.

=back

=cut


