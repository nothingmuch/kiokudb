#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Pixie;
use Moose;

use Carp qw(croak);

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry);

has check_is_storable => (
    isa => "Bool",
    default => 1,
);

sub compile {
    my ( $self, $class ) = @_;

    unless ( $class->can("px_freeze") && $class->can("px_thaw") ) {
        croak "Class $class does not implement px_freeze and px_thaw";
    }

    if ( $self->check_is_storable ) {
        unless ( $class->can("px_is_storable") ) {
            croak "Checking of 'px_is_storable' is enabled but $class does not implement it";
        }

        die "Todo";
    } else {
        die "todo";
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
