#!/usr/bin/perl

package KiokuDB::Meta::Attribute::DoNotSerialize;
use Moose::Role;

use Moose::Util qw(does_role);

use namespace::clean -except => 'meta';

sub Moose::Meta::Attribute::Custom::Trait::KiokuDB::DoNotSerialize::register_implementation { __PACKAGE__ }

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Meta::Attribute::DoNotSerialize - Trait for skipped attributes

=head1 SYNOPSIS

    # in your class:

    package Foo;
    use Moose;

    has bar => (
        traits => [qw(KiokuDB::DoNotSerialize)],
        isa => "Bar",
        is  => "ro",
        lazy_build => 1,
    );

=head1 DESCRIPTION

This L<Moose::Meta::Attribute> trait provides tells L<KiokuDB> to skip an
attribute when serializing.

L<KiokuDB> also recognizes L<MooseX::Meta::Attribute::Trait::DoNotSerialize>,
but if you don't want to install L<MooseX::Storage> you can use this instead.

=cut


