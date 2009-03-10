#!/usr/bin/perl

package KiokuDB::Backend::TypeMap::Default;
use Moose::Role;

use namespace::clean -except => 'meta';

has default_typemap => (
    does => "KiokuDB::Role::TypeMap",
    is   => "ro",
    required   => 1,
    lazy_build => 1,
);

requires "_build_default_typemap";

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::TypeMap::Default - A role for backends with a default typemap

=head1 SYNOPSIS

    package MyBackend;

    with qw(
        ...
        KiokuDB::Backend::TypeMap::Default
    );

    sub _build_default_typemap {
        ...
    }

=head1 DESCRIPTION

This role requires that you implement a single method,
C<_build_default_typemap> that will return a L<KiokuDB::TypeMap> instance.

See L<KiokuDB::TypeMap::Default> for details.

=cut

