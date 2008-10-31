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
