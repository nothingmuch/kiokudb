#!/usr/bin/perl

package KiokuDB::LiveObjects::Scope;
use Moose;

use namespace::clean -except => 'meta';

has objects => (
    isa => "ArrayRef",
    is  => "ro",
    default => sub { [] },
);

sub push {
    my ( $self, @objs ) = @_;
    push @{ $self->objects }, @objs;
}

sub clear {
    my $self = shift;
    @{ $self->objects } = ();
}

has parent => (
    isa => __PACKAGE__,
    is  => "ro",
);

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    required => 1,
);

sub DEMOLISH {
    my $self = shift;

    if ( my $l = $self->live_objects ) {
        if ( my $parent = $self->parent ) {
            $l->_set_current_scope($parent);
        } else {
            $l->_clear_current_scope();
        }
    }

    # FIXME in debug mode detect if @{ $self->objects } = (), but said objects
    # survive the cleanup and warn about them
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Scope - 

=head1 SYNOPSIS

	use KiokuDB::Scope;

=head1 DESCRIPTION

=cut


