#!/usr/bin/perl

package KiokuDB::Set::Deferred;
use Moose;

use Carp qw(croak);

use KiokuDB::Set::Loaded;

use Scalar::Util qw(refaddr);

use namespace::clean -except => 'meta';

with qw(KiokuDB::Set::Storage);

extends qw(KiokuDB::Set::Base);

has _linker => (
    isa => "KiokuDB::Linker",
    is  => "ro",
    required => 1,
    clearer => "_clear_linker",
);

has _live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    lazy_build => 1,
    clearer => "_clear_live_objects",
);

sub _build__live_objects {
    my $self = shift;
    $self->_linker->live_objects;
}

has _live_object_scope => (
    isa => "KiokuDB::LiveObjects::Scope",
    is  => "rw",
    weak_ref => 1,
    clearer  => "_clear_live_object_scope",
);

sub BUILD {
    my $self = shift;
    # can't use lazy build because it doesn't work with weak_ref
    # at any rate we need to capture the current scope at begin time
    $self->_live_object_scope( $self->_live_objects->current_scope );
}

sub loaded { shift->size == 0 }

sub includes {
    my ( $self, @members ) = @_;

    return 1 unless @members;

    return unless $self->size;

    my @ids = grep { defined } $self->_live_objects->objects_to_ids(@members);

    if ( @ids == @members ) {
        # all objects have IDs, so we check
        return $self->_objects->includes(@ids);
    }

    # if they didn't have IDs thenn they are not in storage, and hence not part of the set
    return;
}

sub remove {
    my ( $self, @members ) = @_;

    return 0 unless $self->size or @members;

    my @ids = grep { defined } $self->_live_objects->objects_to_ids(@members);

    return $self->_objects->remove(@ids);
}

sub insert {
    my ( $self, @members ) = @_;

    return unless @members;

    croak "Can't insert non reference into a KiokuDB::Set" if grep { not ref } @members;

    my @ids = grep { defined } $self->_live_objects->objects_to_ids(@members);

    if ( @ids == @members ) {
        if ( my $scope = $self->_live_object_scope ) {
            $scope->push(@members); # keep them around at least as long as us
        }

        # all objects have IDs, no need to load anything
        return $self->_objects->insert(@ids);
    } else {
        $self->_load_all;
        return $self->insert(@members);
    }
}

sub members {
    my $self = shift;

    return unless $self->size;

    $self->_load_all();
    $self->members;
}

sub _load_all {
    my $self = shift;

    # load all the IDs
    my @objects = $self->_linker->get_or_load_objects($self->_objects->members);

    # push all the objects to the set's scope so that they live at least as long as it
    $self->_live_object_scope->push( @objects );

    # replace the ID set with the object set
    $self->_set_objects( Set::Object::Weak->new(@objects) );

    # clear unnecessary structures
    $self->_clear_linker;
    $self->_clear_live_objects;
    $self->_clear_live_object_scope;

    # and swap in loaded behavior
    bless $self, "KiokuDB::Set::Loaded";
}

sub _all_deferred {
    my ( $self, @sets ) = @_;

    my $my_linker = refaddr($self->_linker);

    foreach my $set ( @sets ) {
        return unless $set->isa(__PACKAGE__);
        return unless refaddr($set->_linker) == $my_linker;
    }

    return 1;
}

sub _apply {
    my ( $self, $method, @sets ) = @_;

    if ( $self->_all_deferred(@sets) ) {
        # working in terms of IDs is OK
        my $res = $self->_objects->$method(map { $_->_objects } @sets);
        return $self->meta->clone_object( $self, set => $res );
    } else {
        $self->_load_all;
        return $self->$method(@sets);
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set::Deferred - 

=head1 SYNOPSIS

	use KiokuDB::Set::Deferred;

=head1 DESCRIPTION

=cut


