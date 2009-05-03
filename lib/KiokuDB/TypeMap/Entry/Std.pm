#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Std;
use Moose::Role;

use KiokuDB::TypeMap::Entry::Compiled;

no warnings 'recursion';

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::TypeMap::Entry
    KiokuDB::Role::UUIDs
);

requires "compile_mappings";

has intrinsic => (
    isa => "Bool",
    is  => "ro",
    default => 0,
);

sub compile {
    my ( $self, $class, @args ) = @_;

    my ( $collapse_map, $expand_map, $id_map ) = $self->compile_mappings($class, @args);

    my $collapse = $self->intrinsic
        ? sub { shift->collapse_intrinsic( $collapse_map, @_ ) }
        : sub { shift->collapse_first_class( $collapse_map, @_ ) };

    return KiokuDB::TypeMap::Entry::Compiled->new(
        collapse_method => $collapse,
        expand_method   => $expand_map,
        id_method       => $id_map || "generate_uuid",
        entry           => $self,
        class           => $class,
    );
}

__PACKAGE__

__END__
