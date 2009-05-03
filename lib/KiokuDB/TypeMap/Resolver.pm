#!/usr/bin/perl

package KiokuDB::TypeMap::Resolver;
use Moose;

use Carp qw(croak);

use KiokuDB::TypeMap;
use KiokuDB::TypeMap::Entry::MOP;

use namespace::clean -except => 'meta';

has typemap => (
    does => "KiokuDB::Role::TypeMap",
    is   => "ro",
);

has _compiled => (
    isa => "HashRef",
    is  => "ro",
    default => sub { return {} },
);

sub resolved {
    my ( $self, $class ) = @_;

    exists $self->_compiled->{$class};
}

sub collapse_method {
    my ( $self, $class ) = @_;

    return $self->find_or_resolve($class)->collapse_method;
}

sub expand_method {
    my ( $self, $class ) = @_;

    return $self->find_or_resolve($class)->expand_method;
}

sub id_method {
    my ( $self, $class ) = @_;

    return $self->find_or_resolve($class)->id_method;
}

sub compile_entry {
    my ( $self, $class, $entry ) = @_;

    return $self->register_compiled( $class, $entry->compile($class, $self) );
}

sub register_compiled {
    my ( $self, $class, $compiled ) = @_;

    return ( $self->_compiled->{$class} = $compiled );
}

sub find_or_resolve {
    my ( $self, $class ) = @_;

    return ( $self->_compiled->{$class} || $self->resolve($class) );
}

sub resolve {
    my ( $self, $class ) = @_;

    if ( my $entry = $self->typemap->resolve($class) ) {
        return $self->compile_entry( $class, $entry );
    } else {
        return $self->resolve_fallback($class);
    }
}

sub resolve_fallback {
    my ( $self, $class ) = @_;

    if ( my $meta = Class::MOP::get_metaclass_by_name($class) ) {
        return $self->resolve_fallback_with_meta($class, $meta);
    } else {
        return $self->resolve_fallback_without_meta($class);
    }
}

sub resolve_fallback_with_meta {
    my ( $self, $class, $meta ) = @_;

    # FIXME only allow with Storage?
    return $self->compile_entry( $class => KiokuDB::TypeMap::Entry::MOP->new );
}

sub resolve_fallback_without_meta {
    my ( $self, $class ) = @_;

    croak "$class has no metaclass, please provide a typemap entry or add to the allowed classes";
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Resolver - Caching resolver for L<KiokuDB::TypeMap>

=head1 SYNOPSIS

This object is used by L<KiokuDB::Linker> and L<KiokuDB::Collapser> to map
class names to collapsing/expanding method bodies.

Since L<KiokuDB::TypeMap>s are fairly complex, and L<KiokuDB::TypeMap::Entry>
objects can benefit from specializing to a class by precomputing some things,
resolution is performed once per class, and the results are cached in the
resolver.

=cut
