#!/usr/bin/perl

package MooseX::Storage::Directory::Linker;
use Moose;

use Check::ISA;

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

has live_objects => (
    isa => "MooseX::Storage::Directory::LiveObjects",
    is  => "rw",
    required => 1,
);

has backend => (
    does => "MooseX::Storage::Directory::Backend",
    is  => "rw",
    required => 1,
);

has lazy => (
    isa => "Bool",
    is  => "rw",
    default => 0,
);

sub expand_object {
    my ( $self, $entry, %args ) = @_;

    if ( my $class = $entry->class ) {

        my $instance = $class->get_meta_instance->create_instance();

        # note, this is registered *before* any other value expansion, to allow circular refs
        $self->live_objects->insert( $entry->id => $instance ) unless $args{no_register};

        my $data = $entry->data;

        foreach my $attr ( $class->compute_all_applicable_attributes ) {
            my $name = $attr->name;
            next unless exists $data->{$name};
            my $value = $data->{$name};
            $attr->set_value( $instance, $self->visit($value) );
        }

        return $instance;
    } else {
        my $data = $entry->data;

        $self->live_objects->insert( $entry->id => $data ) unless $args{no_register};

        $self->visit($data);

        return $data;
    }
}

sub visit_object {
    my ( $self, $object ) = @_;

    if ( obj $object, "MooseX::Storage::Directory::Reference" ) {
        # FIXME if $object->is_weak then we need a Data::Visitor api to make
        # sure the container this gets put in is weakened
        # not a huge issue because usually we'll encounter attrs with weak_ref
        # => 1, but this is still needed for correctness
        return $self->get_or_load_object( $object->id );
    } else {
        return $object;
    }
}

sub get_or_load_object {
    my ( $self, $id ) = @_;

    my $l = $self->live_objects;

    if ( defined( my $obj = $l->id_to_object($id) ) ) {
        return $obj;
    } else {
        return $self->lazy
            ? $self->lazy_load_object($id)
            : $self->load_object($id);
    }
}

sub lazy_load_object {
    my ( $self, $id ) = @_;

    require Data::Thunk;

    my $obj = Data::Thunk::lazy_object(sub {
        $self->load_object( $id, no_register => 1 );
    });

    # pre-register the thunk as if it were the object
    # hence the no_register to expand_object
    $self->live_objects->insert( $id => $obj );

    return $obj;
}

sub load_object {
    my ( $self, $id, @args ) = @_;
    $self->expand_object( $self->backend->get($id), @args );
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


