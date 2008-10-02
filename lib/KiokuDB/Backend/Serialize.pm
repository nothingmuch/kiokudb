#!/usr/bin/perl

package KiokuDB::Backend::Serialize;
use Moose::Role;

use namespace::clean -except => 'meta';

requires qw(serialize deserialize);

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Serialize - Serialization role for backends

=head1 SYNOPSIS

    package KiokuDB::Backend::Serialize::Foo;
    use Moose::Role;

    use Foo;

    use namespace::clean -except => 'meta';

    with qw(KiokuDB::Backend::Serialize);

    sub serialize {
        my ( $self, $entry ) = @_;

        Foo::serialize($entry)
    }

    sub deserialize {
        my ( $self, $blob ) = @_;

        Foo::deserialize($blob);
    }

=head1 DESCRIPTION

This role provides provides a consistent way to use serialization modules to
handle backend serialization.

See L<KiokuDB::Backend::Serialize::Storable> and
L<KiokuDB::Backend::Serialize::JSPOn> for examples.

=head1 REQUIRED METHODS

=over 4

=item serializate $entry

Takes a L<KiokuDB::Entry> as an argument. Should return a value suitable for
storage by the backend.

=item deserialize $blob

Takes whatever C<serializate> returned and should inflate and return a
L<KiokuDB::Entry>.

=back
