#!/usr/bin/perl

package KiokuDB::Backend::Serialize::JSPON;
use Moose::Role;

use KiokuDB::Backend::Serialize::JSPON::Expander;
use KiokuDB::Backend::Serialize::JSPON::Collapser;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::TypeMap::Default::JSON
    KiokuDB::Backend::Serialize::JSPON::Converter
);

has expander => (
    isa => "KiokuDB::Backend::Serialize::JSPON::Expander",
    is  => "rw",
    lazy_build => 1,
    handles => [qw(expand_jspon)],
);

sub _build_expander {
    my $self = shift;

    KiokuDB::Backend::Serialize::JSPON::Expander->new($self->_jspon_params);
}

has collapser => (
    isa => "KiokuDB::Backend::Serialize::JSPON::Collapser",
    is  => "rw",
    lazy_build => 1,
    handles => [qw(collapse_jspon)],
);

sub _build_collapser {
    my $self = shift;

    KiokuDB::Backend::Serialize::JSPON::Collapser->new($self->_jspon_params);
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Serialize::JSPON - JSPON serialization helper

=head1 SYNOPSIS

	with qw(KiokuDB::Backend::Serialize::JSPON);

=head1 DESCRIPTION

This serialization role provides JSPON semantics for L<KiokuDB::Entry> and
L<KiokuDB::Reference> objects.

=cut


