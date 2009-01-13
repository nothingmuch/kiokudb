#!/usr/bin/perl

package KiokuDB::TypeMap::ClassBuilders;
use Moose;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::TypeMap);

with qw(KiokuDB::TypeMap::Composite);

has [qw(
    class_accessor_typemap
    object_tiny_typemap
    object_inside_out_typemap
)] => (
    traits     => [qw(KiokuDB::TypeMap)],
    does       => "KiokuDB::Role::TypeMap",
    is         => "ro",
    lazy_build => 1,
);

# Class::Std, Mojo, Badger, Class::MethodMaker, Class::Meta, Class::InsideOut

sub _build_class_accessor_typemap {
    my $self = shift;
    $self->_naive_isa_typemap("Class::Accessor");
}

sub _build_object_tiny_typemap {
    my $self = shift;
    $self->_naive_isa_typemap("Object::Tiny");
}

sub _build_object_inside_out_typemap {
    my $self = shift;

    $self->_create_typemap(
        isa_entries => {
            "Object::InsideOut" => {
                type => "KiokuDB::TypeMap::Entry::StorableHook",
            },
        },
    );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::ClassBuilders - A typemap for standard class builders

=head1 SYNOPSIS

	use KiokuDB::TypeMap::ClassBuilders;

    my $t = KiokuDB::TypeMap::ClassBuilders->new(
        exclude => [qw(object_tiny)],
    );

=head1 DESCRIPTION

This typemap provides entries for some standard class builders from the CPAN.

This class does the L<KiokuDB::TypeMap::Composite> role and can have its sub
maps excluded or overridden.

=head1 SUPPORTED MODULES

=over 4

=item L<Class::Accessor>

=item L<Object::Tiny>

=item L<Object::InsideOut>

=back

=cut


