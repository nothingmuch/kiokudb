#!/usr/bin/perl

package KiokuDB::Cmd::WithDSN;
use Moose::Role;

use namespace::clean -except => 'meta';

has dsn => (
    traits => [qw(Getopt)],
    isa => "Str",
    is  => "ro",
    cmd_aliases => "D",
    documentation => "backend DSN string",
);

has backend => (
    traits => [qw(NoGetopt EarlyBuild)],
    does => "KiokuDB::Backend",
    is   => "ro",
    lazy_build => 1,
);

requires "_build_backend";

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::WithDSN - Role for commands with a C<--dsn> argument.

=head1 DESCRIPTION

This is an abstract role. For concrete implementations see
L<KiokuDB::Cmd::WithDSN::Create>, L<KiokuDB::Cmd::WithDSN::Read> and
L<KiokuDB::Cmd::WithDSN::Write>.

