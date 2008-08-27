#!/usr/bin/perl

package KiokuDB::Backend::Serialize::JSPON::Collapser;
use Moose;

use Check::ISA;
use Devel::PartialDump qw(croak);

use KiokuDB::Entry;
use KiokuDB::Reference;

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

with qw(KiokuDB::Role::StorageUUIDs);

sub collapse_jspon {
    my ( $self, @args ) = @_;
    $self->visit(@args);
}

sub visit_hash_key {
    my ( $self, $key ) = @_;

    if ( $key =~ /^(?: id | \$ref | __CLASS__ | public::.* )$/x ) {
        return "public::$key";
    } else {
        return $key;
    }
}

sub visit_object {
    my ( $self, $object ) = @_;

    if ( obj $object, 'KiokuDB::Reference' ) {
        return { '$ref' => $self->format_uid($object->id), ( $object->is_weak ? ( weak => 1 ) : () ) };
    } elsif ( obj $object, 'KiokuDB::Entry' ) {
        croak("Unsupported data for JSPON: ", $object->data) unless ref($object->data) eq 'HASH';
        return {
            ( $object->has_class ? ( __CLASS__ => $object->class ) : () ),
            id        => $self->format_uid($object->id),
            $self->visit_hash_entries($object->data),
        };
    }

    #return $object; # FIXME maybe we allow this for objects with hooks? not for now
    croak "unexpected object ", $object, " in structure";
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::JSPON::Collapser - Collapse entry data to
JSPON compliant structures

=cut


