#!/usr/bin/perl

package MooseX::Storage::Directory::Resolver;
use Moose;

use MooseX::Storage::Directory::LiveObjects;
use Data::GUID;

use namespace::clean -except => 'meta';

has live_objects => (
    isa => "MooseX::Storage::Directory::LiveObjects",
    is  => "ro",
    required => 1,
    handles  => [qw(ids_to_objects id_to_object)],
);

# get the ID of an object, or make one
sub get_object_id {
    my ( $self, $object ) = @_;

    if ( blessed($object) and $object->can("does") and $object->does("MooseX::Storage::Directory::UID") ) {
        return $object->storage_uid;
    } else {
        return $self->generate_id;
    }
}

sub generate_id {
    my $self = shift;
    Data::GUID->new->as_string;
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


