#!/usr/bin/perl

package MooseX::Storage::Directory::Linker;
use Moose;

use Check::ISA;

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

# FIXME has a backend and a live objects?
has directory => (
    isa => "MooseX::Storage::Directory",
    is  => "rw",
    required => 1,
    is_weak  => 1,
    handles => [qw(lookup)],
);

has lazy => (
    isa => "Bool",
    is  => "rw",
    default => 0,
);

sub expand_object {
    my ( $self, $entry ) = @_;

    if ( my $class = $entry->class ) {

        my $instance = $class->get_meta_instance->create_instance();

        $self->directory->live_objects->insert( $entry->id => $instance );

        my $data = $entry->data;

        foreach my $attr ( $class->compute_all_applicable_attributes ) {
            my $value = $data->{ $attr->name };
            $attr->set_value( $instance, $self->visit( $value ) );
        }

        return $instance;
    } else {
        return $entry->data;
    }
}

sub visit_object {
    my ( $self, $object ) = @_;

    if ( obj $object, "MooseX::Storage::Directory::Reference" ) {
        if ( $self->lazy ) {
            # inject a Data::Thunk::Object to the live object cache:
            # $object->id => lazy_object { $self->expand_object( $backend->get($id) ) }
        }
        return $self->lookup($object->id);
    } else {
        return $object;
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::Storage::Directory::Linker - Relinks live objects from storage entries

=head1 SYNOPSIS

=head1 DESCRIPTION

This object reconnects and blesses entry data using the MOP to recreate the
connected graph in memory.

If a live object already exists for a UID then that object will be reused.

=head1 TODO

=over 4

=item *

Ultra-sleazy L<Data::Thunk> based lazy loading of references

=back

=cut


