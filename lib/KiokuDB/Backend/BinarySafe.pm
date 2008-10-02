#!/usr/bin/perl

package KiokuDB::Backend::BinarySafe;
use Moose::Role;

use namespace::clean -except => 'meta';

# informative role

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::BinarySafe - An informational role for binary data safe
backends.

=head1 SYNOPSIS

    package KiokuDB::Backend::MySpecialBackend;
    use Moose;

    use namespace::clean -except => 'meta';

    with qw(KiokuDB::Backend::BinarySafe);

=head1 DESCRIPTION

This backend is an informational role for backends which can store arbitrary
binary strings.

This mostly has to do with L<KiokuDB::Backend::Serialize> variants (e.g.
L<Storable> based serialization is binary safe, while
L<KiokuDB::Backend::Serialize::JSPON> is not).

