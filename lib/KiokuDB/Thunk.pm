#!/usr/bin/perl

package KiokuDB::Thunk;
use Moose;

use namespace::clean -except => 'meta';

has id => (
    isa => "Str",
    is  => "ro",
    required => 1,
);

has linker => (
    isa => "KiokuDB::Linker",
    is  => "ro",
);

has attr => (
    isa => "Class::MOP::Attribute",
    is  => "ro",
);

has value => (
    isa => "Ref",
    is  => "ro",
    lazy_build => 1,
);

sub _build_value {
    my $self = shift;
    $self->linker->get_or_load_object($self->id);
}

sub vivify {
    my ( $self, $instance ) = @_;

    my $value = $self->value;

    $self->attr->set_value( $instance, $value );

    return $value;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
