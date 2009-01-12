#!/usr/bin/perl

package KiokuDB::Serializer;
use Moose::Role;

use Carp qw(croak);

use Moose::Util::TypeConstraints;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Backend::Serialize);

requires "serialize_to_stream";
requires "deserialize_from_stream";

my %types = (
    storable => "KiokuDB::Serializer::Storable",
    json     => "KiokuDB::Serializer::JSON",
    yaml     => "KiokuDB::Serializer::YAML",
);

coerce( __PACKAGE__,
    from Str => via {
        my $class = $types{lc($_)} or croak "unknown format: $_";;
        Class::MOP::load_class($class);
        $class->new;
    },
    from HashRef => via {
        my %args = %$_;
        my $class = $types{lc(delete $args{format})} or croak "unknown format: $args{format}";
        Class::MOP::load_class($class);
        $class->new(%args);
    },
);

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Serializer - Standalone serializer object

=head1 SYNOPSIS

    Backend->new(
        serializer => KiokuDB::Serializer::Storable->new( ... ),
    );

=head1 DESCRIPTION

This role is for objects which perform the serialization roles (e.g.
L<KiokuDB::Backend::Serialize::Storable>) but can be used independently.

This is used by L<KiokuDB::Backend::Serialize::Delegate> and
L<KiokuDB::Cmd::DumpFormatter>.
