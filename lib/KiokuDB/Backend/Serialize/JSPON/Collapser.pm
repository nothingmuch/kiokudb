#!/usr/bin/perl

package KiokuDB::Backend::Serialize::JSPON::Collapser;
use Moose;

use KiokuDB::Entry;
use KiokuDB::Reference;

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

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

    if ( ref($object) eq 'KiokuDB::Reference' ) {
        return { '$ref' => $object->id . ".data", ( $object->is_weak ? ( weak => 1 ) : () ) };
    } elsif ( ref($object) eq 'KiokuDB::Entry' ) {
        my $id = $object->id;
        return {
            ( $object->has_class ? ( __CLASS__ => $object->class ) : () ),
            ( $id ? ( id => $id ) : () ),
            data => $self->visit($object->data),
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


