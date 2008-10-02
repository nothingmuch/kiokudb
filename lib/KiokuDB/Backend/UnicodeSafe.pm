#!/usr/bin/perl

package KiokuDB::Backend::UnicodeSafe;
use Moose::Role;

use namespace::clean -except => 'meta';

# informative

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::UnicodeSafe - An informational role for binary data safe
backends.

=head1 SYNOPSIS

    package KiokuDB::Backend::MySpecialBackend;
    use Moose;

    use namespace::clean -except => 'meta';

    with qw(KiokuDB::Backend::UnicodeSafe);

=head1 DESCRIPTION

This backend is an informational role for backends which can store unicode perl
strings safely.

This means that B<character> strings inserted to the database will not be
retreived as B<byte> strings upon deserialization.

This mostly has to do with L<KiokuDB::Backend::Serialize> variants.

