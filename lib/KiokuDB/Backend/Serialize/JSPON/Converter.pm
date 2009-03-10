#!/usr/bin/perl

package KiokuDB::Backend::Serialize::JSPON::Converter;
use Moose::Role;

use namespace::clean -except => 'meta';

use constant _jspon_fields => qw(
    id
    class
    class_meta
    root
    deleted
    tied
    ref
    data
);

has id_field => (
    isa => "Str",
    is  => "ro",
    default => "id",
);

has class_field => (
    isa => "Str",
    is  => "ro",
    default => "__CLASS__",
);

has class_meta_field => (
    isa => "Str",
    is  => "ro",
    default => "__META__",
);

has root_field => (
    isa => "Str",
    is  => "ro",
    default => "root",
);

has deleted_field => (
    isa => "Str",
    is  => "ro",
    default => "deleted",
);

has tied_field => (
    isa => "Str",
    is  => "ro",
    default => "tied",
);

has ref_field => (
    isa => "Str",
    is  => "ro",
    default => '$ref',
);

has data_field => (
    isa => "Str",
    is  => "ro",
    default => "data",
);

has inline_data => (
    isa => "Bool",
    is  => "ro",
    default => 0,
);

# kinda ugly, used to pass options down to expander/collapser from backend
has _jspon_params => (
    isa => "HashRef",
    is  => "ro",
    lazy_build => 1,
);

sub _build__jspon_params {
    my $self = shift;

    return {
        ( map {
            my $name = "${_}_field";
            $name => $self->$name
        } $self->_jspon_fields,
        ),
        ( inline_data => $self->inline_data ? 1 : 0 ),
    };
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Serialize::JSPON::Converter - Common functionality for JSPON
expansion/collapsing

=head1 SYNOPSIS

    # internal

=head1 DESCRIPTION

These attributes are shared by both
L<KiokuDB::Backend::Serialize::JSPON::Converter> and
L<KiokuDB::Backend::Serialize::JSPON::Expander>.

These attributes are also available in L<KiokuDB::Backend::Serialize::JSPON>
and passed to the constructors of the expander and the collapser.

=head1 ATTRIBUTES

=over 4

=item id_field

=item class_field

=item class_meta_field

=item root_field

=item deleted_field

=item tied_field

=item data_field

=item ref_field

The various field name mappings for the L<KiokuDB::Entry> attributes.

Everything defaults to the attribute name, except C<class> and C<class_meta>
which default to C<__CLASS__> and C<__META__> for compatibility with
L<MooseX::Storage> when C<inline_data> is set, and C<ref_field> which is set to
C<$ref> according to the JSPON spec.

=item inline_data

Determines whether or not the entry data keys are escaped and the data is
stored in the same top level mapping, or inside a the C<data_field> key.

=back

=cut
