#!/usr/bin/perl

package KiokuDB::TypeMap::Resolver;
use Moose;

use KiokuDB::TypeMap;
use KiokuDB::TypeMap::Entry::MOP;

use namespace::clean -except => 'meta';

has typemap => (
    does => "KiokuDB::Role::TypeMap",
    is   => "ro",
);

has [qw(_collapse _expand _id)] => (
    isa => "HashRef",
    is  => "ro",
    default => sub { return {} },
);

sub resolved {
    my ( $self, $class ) = @_;

    exists $self->_collapse->{$class};
}

sub collapse_method {
    my ( $self, $class ) = @_;

    if ( my $method = $self->_collapse->{$class} ) {
        return $method;
    } else {
        $self->resolve($class);
        return $self->_collapse->{$class};
    }
}

sub expand_method {
    my ( $self, $class ) = @_;

    if ( my $method = $self->_expand->{$class} ) {
        return $method;
    } else {
        $self->resolve($class);
        return $self->_expand->{$class};
    }
}

sub id_method {
    my ( $self, $class ) = @_;

    if ( my $method = $self->_id->{$class} ) {
        return $method;
    } else {
        $self->resolve($class);
        return $self->_id->{$class};
    }
}

sub compile_entry {
    my ( $self, $class, $entry ) = @_;

    $self->register_compiled( $class, $entry->compile($class) );
}

sub register_compiled {
    my ( $self, $class, $collapse, $expand, $id ) = @_;
    $self->_collapse->{$class} = $collapse;
    $self->_expand->{$class}   = $expand;
    $self->_id->{$class}       = $id;
}

sub resolve {
    my ( $self, $class ) = @_;

    if ( my $entry = $self->typemap->resolve($class) ) {
        $self->compile_entry( $class, $entry );
    } else {
        $self->resolve_fallback($class);
    }

    return;
}

sub resolve_fallback {
    my ( $self, $class ) = @_;

    if ( my $meta = Class::MOP::get_metaclass_by_name($class) ) {
        $self->resolve_fallback_with_meta($class, $meta);
    } else {
        $self->resolve_fallback_without_meta($class);
    }
}

sub resolve_fallback_with_meta {
    my ( $self, $class, $meta ) = @_;

    # FIXME only allow with Storage?
    return $self->compile_entry( $class => KiokuDB::TypeMap::Entry::MOP->new );
}

sub resolve_fallback_without_meta {
    my ( $self, $class ) = @_;

    die "todo ($class has no fallback, no meta)";
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
