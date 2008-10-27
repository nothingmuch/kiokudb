#!/usr/bin/perl

package KiokuDB::Meta::Attribute::Lazy;
use Moose::Role;

use Moose::Util qw(does_role);

use namespace::clean -except => 'meta';

sub Moose::Meta::Attribute::Custom::Trait::KiokuDB::Lazy::register_implementation { __PACKAGE__ }

before attach_to_class => sub {
    my ( $self, $class ) = @_;

    my $mi = $class->get_meta_instance;

    unless ( does_role( $mi, "KiokuDB::Meta::Instance" ) ) {
        $self->throw_error("Can't attach to a class whose meta instance doesn't do KiokuDB::Meta::Instance", data => $class );
    }
};

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Meta::Attribute::Lazy - Trait for lazy loaded attributes

=head1 SYNOPSIS

    # in your class:

    package Foo;
    use KiokuDB::Class;

    has bar => (
        traits => [qw(KiokuDB::Lazy)],
        isa => "Bar",
        is  => "ro",
    );



    # Later:

    my $foo = $dir->lookup($id);

    # bar is not yet loaded, it will be lazily fetched during this call:
    $foo->bar;

=head1 DESCRIPTION

This L<Moose::Meta::Attribute> trait provides lazy loading on a per field basis
for objects stored in L<KiokuDB>.

Instead of using proxy objects with AUTOLOAD, overloading, or similar hacks,
you can declaratively specify which attributes you want to make lazy, and this
will be done cleanly through the MOP.

This is implemented by using a placeholder object, L<KiokuDB::Thunk> which
contains references to the ID and the linker, and L<KiokuDB::Meta::Instance>
will know to replace the placeholder with the actual loaded object when it is
fetched from the object by an accessor.

=cut


