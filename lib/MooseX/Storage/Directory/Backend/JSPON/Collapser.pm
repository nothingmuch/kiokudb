#!/usr/bin/perl

package MooseX::Storage::Directory::Backend::JSPON::Collapser;
use Moose;

use Check::ISA;
use Carp qw(croak);

use MooseX::Storage::Directory::Entry;
use MooseX::Storage::Directory::Reference;

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

    if ( obj $object, 'MooseX::Storage::Directory::Reference' ) {
        return { '$ref' => $object->id . '.json', ( $object->is_weak ? ( is_weak => 1 ) : () ) };
    } elsif ( obj $object, 'MooseX::Storage::Directory::Entry' ) {
        return {
            __CLASS__ => $object->class->identifier,
            id        => $object->id . '.json',
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

MooseX::Storage::Directory::Backend::JSPON::Collapser - Collapse entry data to
JSPON compliant structures

=cut


