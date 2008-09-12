#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Callback;
use Moose;

use Data::Swap qw(swap);

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

has [qw(collapse expand)] => (
    is  => "ro",
    isa => "Str|CodeRef",
    required => 1,
);

sub compile_mappings {
    my ( $self, @args ) = @_;

    my $collapse_object = $self->collapse;
    my $collapse = sub {
        my ( $self, %args ) = @_;

        return [ map { $self->visit($_) } $args{object}->$collapse_object() ];
    };

    my $expand_object = $self->expand;
    my $expand = sub {
        my ( $self, $entry ) = @_;

        # FIXME see Linker::expand_naive

        my $placeholder = {};
        $self->register_object( $entry => $placeholder );

        my @args = map { $self->inflate_data($_) } @{ $entry->data };

        my $object = $entry->class->$expand_object(@args);

        swap($object, $placeholder);
        return $placeholder;
    };

    return ( $collapse, $expand );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
