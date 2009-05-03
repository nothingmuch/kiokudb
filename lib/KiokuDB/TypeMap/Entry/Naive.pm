#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Naive;
use Moose;

no warnings 'recursion';

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

sub compile_collapse_body {
    my ( $self, $class ) = @_;

    return sub {
        my ( $self, %args ) = @_;

        my $object = $args{object};

        return $self->make_entry(
            %args,
            data => $self->visit_ref_data($object),
        );
    };
}

sub compile_expand {
    my ( $self, $class ) = @_;

    return sub {
        my ( $self, $entry ) = @_;

        $self->inflate_data( $entry->data, \( my $obj ), $entry );

        bless $obj, $class;
    };
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::Naive - A typemap entry for "simple" objects

=head1 SYNOPSIS

    KiokuDB::TypeMap->new(
        entires => {
            'My::Class' => KiokuDB::TypeMap::Entry::Naive->new,
        },
    );

=head1 DESCRIPTION

This typemap entry is suitable for plain objects that can be stored by simply
walking them recursively.

Most objects fall into this category, but there are notable exceptions:

=over 4

=item XS based objects, using a pointer as a number

When being deserialized the pointer value will no longer be valid, causing
segfaults.

=item Inside out objects

Since the referant is really a flyweight object with no data, the object will
be missing its attributes and a suitable typemap entry is required instead.

This applies to any object interacting with a global state of some sort.

=item Objects with magic

Perl SV level magic is not retained, apart from tied values.

=back

=head1 ATTRIBUTES

=over 4

=item intrinsic

If true the object will be collapsed without an ID as part of its parent.

=back
