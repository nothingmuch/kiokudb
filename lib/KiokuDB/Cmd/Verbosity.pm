#!/usr/bin/perl

package KiokuDB::Cmd::Verbosity;
use Moose::Role;

use MooseX::Getopt;

with qw(KiokuDB::Role::Verbosity);

use namespace::clean -except => 'meta';

has verbose => (
    traits => [qw(Getopt)],
    isa => "Bool",
    is  => "ro",
    cmd_aliases => "v",
    documentation => "more output",
);

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
