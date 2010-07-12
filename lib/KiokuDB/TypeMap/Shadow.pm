#!/usr/bin/perl

package KiokuDB::TypeMap::Shadow;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Role::TypeMap);

has typemaps => (
    does => "ArrayRef[KiokuDB::Role::TypeMap]",
    is   => "ro",
    required => 1,
);

sub resolve {
    my ( $self, @args ) = @_;

    foreach my $typemap ( @{ $self->typemaps } ) {
        if ( my $entry = $typemap->resolve(@args) ) {
            return $entry;
        }
    }

    return;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Shadow - Try a list of L<KiokuDB::TypeMap>s in order

=head1 SYNOPSIS

    KiokuDB->new(
        backend => ...,
        typemap => KiokuDB::TypeMap::Shadow->new(
            typemaps => [
                $first,
                $second,
            ],
        ),
    );

=head1 DESCRIPTION

This class is useful for performing mixin inheritance like merging of typemaps,
by shadowing an ordered list.

This is used internally to overlay the user typemap on top of the
L<KiokuDB::TypeMap::Default> instance provided by the backend.

This differs from using C<includes> in L<KiokuDB::TypeMap> because that
inclusion is computed symmetrically, like roles.

=cut
