#!/usr/bin/perl

package KiokuDB::Role::Verbosity;
use Moose::Role;

use namespace::clean -except => 'meta';

has verbose => (
    isa => "Bool",
    is  => "ro",
);

sub BUILD {
    my $self = shift;

    STDERR->autoflush(1) if $self->verbose;
}

sub v {
    my $self = shift;
    return unless $self->verbose;

    STDERR->print(@_);
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Role::Verbosity - A role for printing diagnosis to STDERR

=head1 SYNOPSIS

    $self->v("blah blah\n"); # only printed if $self->verbose is true

=head1 DESCRIPTION

This role provides the C<verbose> attribute and a C<v> method that you can use
to emit verbose output to C<STDERR>.
