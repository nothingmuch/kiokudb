#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Naive;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

sub compile_mappings {
    my ( $self, $class ) = @_;

    return (
        sub {
            my ( $self, %args ) = @_;

            my $object = $args{object};

            return $self->visit_ref_data($object);
        },
        sub {
            my ( $self, $entry ) = @_;

            $self->inflate_data( $entry->data, \( my $obj ), $entry );

            bless $obj, $class;
        },
    );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
