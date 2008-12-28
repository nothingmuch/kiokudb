#!/usr/bin/perl

package KiokuDB::Backend::Serialize::JSPON::Collapser;
use Moose;

use KiokuDB::Entry;
use KiokuDB::Reference;
use JSON;

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

with qw(KiokuDB::Backend::Serialize::JSPON::Converter);

has reserved_key => (
    isa => "Regexp",
    is  => "ro",
    lazy_build => 1,
);

sub _build_reserved_key {
    my $self = shift;

    my $reserved = '^(?:' . join("|", map { quotemeta($self->$_) } map { $_ . "_field" } $self->_jspon_fields) . ')$';

    qr/(?: $reserved | ^public:: )/x
}

sub collapse_jspon {
    my ( $self, @args ) = @_;
    $self->visit(@args);
}

sub visit_hash_key {
    my ( $self, $key ) = @_;

    if ( $key =~ $self->reserved_key ) {
        return "public::$key";
    } else {
        return $key;
    }
}

sub visit_object {
    my ( $self, $object ) = @_;

    if ( ref($object) eq 'KiokuDB::Reference' ) {
        return {
            $self->ref_field => $object->id . ( $self->inline_data ? "" : "." . $self->data_field ),
            ( $object->is_weak ? ( weak => 1 ) : () ),
        };
    } elsif ( ref($object) eq 'KiokuDB::Entry' ) {
        my $id = $object->id;
        return {
            ( $object->has_class ? ( $self->class_field => $object->class ) : () ),
            ( $object->has_class_meta ? ( $self->class_meta_field => $object->class_meta ) : () ),
            ( $id ? ( $self->id_field => $id ) : () ),
            ( $object->root ? ( $self->root_field => JSON::true() ) : () ),
            ( $object->deleted ? ( $self->deleted_field => JSON::true() ) : () ),
            ( $object->has_tied ? ( $self->tied_field => $object->tied ) : () ),
            ( $self->inline_data
                ? %{ $self->visit($object->data) }
                : ( $self->data_field => $self->visit($object->data) )
            ),
        };
    } else {
        return $object; # we let JSON complain about objects
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Serialize::JSPON::Collapser - Collapse entry data to
JSPON compliant structures

=head1 SYNOPSIS

    my $c = KiokuDB::Backend::Serialize::JSPON::Collapser->new(
        id_field => "_id",
    );

    my $hashref = $c->collapse_jspon($entry);

=head1 DESCRIPTION

This object is used by L<KiokuDB::Backend::Serialize::JSPON> to convert
L<KiokuDB::Entry> objects to JSPON compliant structures.

=head1 ATTRIBUTES

See L<KiokuDB::Backend::Serialize::JSPON::Converter> for attributes shared by
L<KiokuDB::Backend::Serialize::JSPON::Collapser> and
L<KiokuDB::Backend::Serialize::JSPON::Expander>.

=head1 METHODS

=over 4

=item collapse_jspon $entry

Collapses the entry recursively, returning a JSPON compliant data structure
suitable for serialization as a JSON string.

=back

=cut

