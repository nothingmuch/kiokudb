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

    my $reserved = '^(?:' . join("|", map { quotemeta($self->$_) } qw(id_field class_field root_field deleted_field tied_field ref_field)) . ')$';

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

KiokuDB::Backend::JSPON::Collapser - Collapse entry data to
JSPON compliant structures

=cut


