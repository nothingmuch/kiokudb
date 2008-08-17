#!/usr/bin/perl

package MooseX::Storage::Directory::Resolver;
use Moose;

use MooseX::Storage::Directory ();
use MooseX::Storage::Directory::LiveObjects;

use namespace::clean -except => 'meta';

with qw(MooseX::Storage::Directory::Role::UUIDs);

has live_objects => (
    isa => "MooseX::Storage::Directory::LiveObjects",
    is  => "ro",
    required => 1,
    handles  => [qw(ids_to_objects id_to_object remove)],
);

# get the ID of an object, or make one
sub get_object_id {
    my ( $self, $object ) = @_;

    # FIXME Objects of this sort will probably do their own pre-resolution,
    # with an MXSD instance belonging to the metaclass. I don't think we can do
    # any of this yet, and that it will emerge from the first real moose poop
    # impl.

    #if ( blessed($object) and $object->can("does") and $object->does("MooseX::Storage::Directory::UID") ) {
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

    foreach my $obj ( @objects ) {
        my $id;

        unless ( $id = $l->object_to_id($obj) ) {
            $id = $self->get_object_id($obj);
            $l->insert( $id => $obj );
        }

        push @ids, $id;
    }

    if ( @objects == 1 ) {
        return $ids[0]; # DWIM in scalar context
    } else {
        return @ids;
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::Storage::Directory::Resolver - UID <-> refaddr mapping

=head1 SYNOPSIS

    use MooseX::Storage::Directory::Resolver;

=head1 DESCRIPTION

This object wraps the live object set but also handles UID extraction and
generation.

=cut


