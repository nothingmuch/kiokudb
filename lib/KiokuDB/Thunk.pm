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

=pod

=head1 NAME

KiokuDB::Thunk - Internal only placeholder for deferred objects

=head1 SYNOPSIS

    # do not use directly,
    # KiokuDB::Meta::Attribute::Lazy, KiokuDB::Meta::Instance and
    # KiokuDB::TypeMap::Entry::MOP will do the actual thunking of data so that
    # the thunk will never be visible unless you break encapsulation.

=head1 DESCRIPTION

This is an internal placeholder object. It will be used on attributes that you
mark with L<KiokuDB::Meta::Attribute::Lazy> automatically, and should never be
visible to the user because L<KiokuDB::Meta::Instance> will automatically
inflate it before it's even seen by the accessor's code.

