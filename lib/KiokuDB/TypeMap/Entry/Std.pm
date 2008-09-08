#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Std;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry);

requires "compile_mappings";

has intrinsic => (
    isa => "Bool",
    is  => "ro",
    default => 0,
);

sub compile {
    my ( $self, @args ) = @_;

    my ( $collapse_map, $expand_map ) = $self->compile_mappings(@args);

    my $collapse = $self->intrinsic
        ? sub { shift->collapse_intrinsic( $collapse_map, @_ ) }
        : sub { shift->collapse_first_class( $collapse_map, @_ ) };

    return ( $collapse, $expand_map );
}

__PACKAGE__

__END__
