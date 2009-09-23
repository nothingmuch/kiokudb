#!/usr/bin/perl

package KiokuDB::Set::Loaded;
use Moose;

use Carp qw(croak);

use namespace::clean -except => 'meta';

with qw(KiokuDB::Set::Storage);

extends qw(KiokuDB::Set::Base);

sub loaded { 1 }

sub includes { shift->_objects->includes(@_) }
sub remove   { shift->_objects->remove(@_) }
sub members  { shift->_objects->members }

sub insert   {
    my ( $self, @objects ) = @_;
    croak "Can't insert non reference into a KiokuDB::Set" if grep { not ref } @objects;
    $self->_objects->insert(@objects)
}

sub _set_ids {
    my ( $self, $id_set ) = @_;

    # replace the object set with the ID set
    $self->_set_objects( $id_set );

    # and go back to being deferred
    bless $self, "KiokuDB::Set::Deferred";
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set::Loaded - Implementation of loaded sets

=head1 SYNOPSIS

    # created automatically when deferred sets are vivified

=head1 DESCRIPTION

This is the implementation of a loaded set. A L<KiokuDB::Set::Deferred>
automatically upgrades into a loaded set when its set members are retrieved.

=cut


