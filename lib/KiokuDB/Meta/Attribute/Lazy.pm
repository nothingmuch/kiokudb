#!/usr/bin/perl

package KiokuDB::Meta::Attribute::Lazy;
use Moose::Role;

use namespace::clean -except => 'meta';

sub Moose::Meta::Attribute::Custom::Trait::KiokuDB::Lazy::register_implementation { __PACKAGE__ }

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Meta::Attribute::Lazy - Trait for lazy loaded attributes

=head1 SYNOPSIS

    # in your class:

    package Foo;
    use Moose;

    use KiokuDB::Meta::Attribute::Lazy;

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

Instead of using proxy objects/thunks or similar hacks, you can declaratively
specify which attributes you want to make lazy, and this will be done cleanly
through the MOP.

=cut


