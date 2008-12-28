#!/usr/bin/perl

package KiokuDB::Backend::Serialize::Delegate;
use Moose::Role;

use KiokuDB::Serializer;

use namespace::clean -except => 'meta';

has serializer => (
    isa     => "KiokuDB::Serializer",
    is      => "ro",
    coerce  => 1,
    default => "storable",
    handles => [qw(serialize deserialize)],
);

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Serialize::Delegate - Use a L<KiokuDB::Serializer> object
instead of a role to handle serialization in a backend.

=head1 SYNOPSIS

    package MyBackend;
    use Moose;

    with qw(
        ...
        KiokuDB::Backend::Serialize::Delegate
    );



    MyBackend->new(
        serializer => "yaml",
    );

=head1 DESCRIPTION

This role provides a C<serialzier> attribute (by default
L<KiokuDB::Serializer::Storable>) with coercions from a moniker string for easy
serialization format selection.

