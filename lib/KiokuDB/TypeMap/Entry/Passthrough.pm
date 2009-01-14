#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Passthrough;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry);

has intrinsic => (
    isa => "Bool",
    is  => "ro",
    default => 0,
);

sub compile {
    my ( $self, @args ) = @_;

    if ( $self->intrinsic ) {
        return (
            sub { $_[1] },
            sub { $_[1]->data }, # only called on an Entry, if the object is just an object, this won't be called
            "generate_uuid",
        );
    } else {
        return (
            sub {
                my ( $collapser, @args ) = @_;

                $collapser->collapse_first_class(
                    sub {
                        my ( $collapser, %args ) = @_;
                        return $collapser->make_entry(
                            %args,
                            data => $args{object},
                        );
                    },
                    @args,
                );
            },
            sub {
                my ( $linker, $entry ) = @_;
                return $entry->data;
            },
            "generate_uuid",
        );
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::Passthrough - A typemap entry of objects that will be
serialized by the backend.

=head1 SYNOPSIS

    KiokuDB::TypeMap->new(
        entires => {
            'Value::Object' => KiokuDB::TypeMap::Entry::Naive->new,
        },
    );

=head1 DESCRIPTION

This typemap entry delegates the handling of certain objects to the backend.

A prime example is L<DateTime> being handled by
L<KiokuDB::Backend::Serialize::Storable>. L<DateTime> has efficient L<Storable>
hooks, and does not refer to any domain objects, so it is safe to assume that
it can just be passed through for serialization.

=head1 ATTRIBUTES

=over 4

=item intrinsic

If true the object will be just left in place.

If false, the object will get its own ID and entry, and the object will be in
the C<data> field of that entry.

=back
