#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Passthrough;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry);

has intrinsic => (
    isa => "Bool",
    is  => "ro",
    default => 0,
);

sub compile {
    my ( $self, @args ) = @_;

    if ( $self->intrinsic ) {
        return (
            sub { $_[1] },
            sub { $_[1]->data }, # only called on an Entry, if the object is just an object, this won't be called
            "generate_uuid",
        );
    } else {
        return (
            sub {
                my ( $collapser, @args ) = @_;

                $collapser->collapse_first_class(
                    sub {
                        my ( $collapser, %args ) = @_;
                        return $args{object};
                    },
                    @args,
                );
            },
            sub {
                my ( $linker, $entry ) = @_;
                return $entry->data;
            },
            "generate_uuid",
        );
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
