package KiokuDB::TypeMap::Entry::Std::Intrinsic;
use Moose::Role;

no warnings 'recursion';

use namespace::clean -except => 'meta';

requires qw(compile_collapse_body);

has intrinsic => (
    isa => "Bool",
    is  => "ro",
    predicate => "has_intrinsic",
);

sub should_compile_intrinsic {
    my ( $self, $class, @args ) = @_;

    return $self->intrinsic;
}

sub compile_collapse {
    my ( $self, @args ) = @_;

    if ( $self->should_compile_intrinsic(@args) ) {
        return $self->compile_intrinsic_collapse(@args);
    } else {
        return $self->compile_first_class_collapse(@args);
    }
}

sub compile_intrinsic_collapse {
    my ( $self, @args ) = @_;

    $self->compile_collapse_wrapper( collapse_intrinsic => @args );
}

sub compile_first_class_collapse {
    my ( $self, @args ) = @_;

    $self->compile_collapse_wrapper( collapse_first_class => @args );
}

sub compile_collapse_wrapper {
    my ( $self, $method, $class, @args ) = @_;

    my ( $body, @extra ) = $self->compile_collapse_body($class, @args);

    return sub {
        my ( $collapser, $obj, @args ) = @_;
        
        $collapser->$method( $body, $obj, @extra, @args );
    }
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::Std::Intrinsic - Provides a compile_collapse
implementation.

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

This role provides a compile_collapse implementation by breaking it down
and requiring the implementation of a 'compile_collapse_body' method.

=head1 REQUIRED METHODS

=over 4

=item compile_collapse_body

Must return a code reference or a method name.  The method is called on
the L<KiokuDB::Collapser>, with a hash of parameters.  The parameters can
include (but are not limited to) the following:

=over 8

=item object

The object to collapse.

=item id

The id under which the object is to be stored.

=item class

The type of C<object>.

=back

The method should return a L<KiokuDB::Reference> object.

=back

=cut
