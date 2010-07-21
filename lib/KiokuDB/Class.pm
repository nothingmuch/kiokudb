#!/usr/bin/perl

package KiokuDB::Class;

use strict;
use warnings;

use Moose ();
use Moose::Exporter;
use Moose::Util::MetaRole;

use KiokuDB::Meta::Instance;
use KiokuDB::Meta::Attribute::Lazy;

use namespace::clean -except => 'meta';

Moose::Exporter->setup_import_methods( also => 'Moose' );

sub init_meta {
    my ( $class, %args ) = @_;

    my $for_class = $args{for_class};

    Moose->init_meta(%args);

    Moose::Util::MetaRole::apply_metaroles(
        for             => $for_class,
        class_metaroles => {
            instance => [qw(KiokuDB::Meta::Instance)],
        },
    );

    return Class::MOP::get_metaclass_by_name($for_class);
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Class - L<KiokuDB> specific metaclass

=head1 SYNOPSIS

    package Foo;
    use KiokuDB::Class; # instead of Moose

    has bar => (
        traits => [qw(KiokuDB::Lazy)],
        ...
    );

=head1 DESCRIPTION

This L<Moose> wrapper provides some metaclass extensions in order to more
tightly integrate your class with L<KiokuDB>.

Currently only L<KiokuDB::Meta::Attribute::Lazy> is set up (by extending
L<Moose::Meta::Instance> with a custom role to support it), but in the future
indexing, identity, and various optimizations will be supported by this.

=cut

