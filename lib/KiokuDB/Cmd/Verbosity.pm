#!/usr/bin/perl

package KiokuDB::Cmd::Verbosity;
use Moose::Role;

use namespace::clean -except => 'meta';

has verbose => (
    isa => "Bool",
    is  => "ro",
    cmd_aliases => "v",
    documentation => "more output",
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

KiokuDB::Cmd::Verbosity - A role for command line tools that have a C<--verbose> option.

=head1 SYNOPSIS

    $self->v("blah blah\n"); # only printed if --verbose is specified

=head1 DESCRIPTION

This role provides the C<verbose> attribute and command line option, and a C<v>
method that you can use to emit verbose output to C<STDERR>.
