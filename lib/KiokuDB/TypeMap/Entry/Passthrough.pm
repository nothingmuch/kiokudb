#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Passthrough;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

sub compile_mappings {
    my ( $self, $class ) = @_;

    return (
        sub {
            my ( $collapser, %args ) = @_;
            return $args{object};
        },
        sub {
            my ( $linker, $entry ) = @_;
            return $entry->data;
        },
    );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
