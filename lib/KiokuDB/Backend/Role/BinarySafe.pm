#!/usr/bin/perl

package KiokuDB::Backend::Role::BinarySafe;
use Moose::Role;

use namespace::clean -except => 'meta';

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Role::BinarySafe - An informational role for binary data safe
backends.

=head1 SYNOPSIS

    package KiokuDB::Backend::MySpecialBackend;
    use Moose;

    use namespace::clean -except => 'meta';

    with qw(KiokuDB::Backend::Role::BinarySafe);

=head1 DESCRIPTION

This backend is an informational role for backends which can store arbitrary
binary strings, especially utf8 data as bytes (without reinterpreting it as
unicode strings when inflating).

This mostly has to do with L<KiokuDB::Backend::Serialize> variants (for example
L<KiokuDB::Backend::Serialize::Storable> is binary safe, while
L<KiokuDB::Backend::Serialize::JSON> is not).

