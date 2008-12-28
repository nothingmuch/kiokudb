#!/usr/bin/perl

package KiokuDB::Cmd::DumpFormatter;
use Moose::Role;

use Moose::Util::TypeConstraints;

use KiokuDB::Serializer;

use namespace::clean -except => 'meta';

has format => (
    is  => "ro",
    default => "yaml",
    cmd_aliases => "f",
    documentation => "dump format ('yaml', 'storable', etc)"
);

has serializer => (
    traits => [qw(NoGetopt EarlyBuild)],
    isa => "KiokuDB::Serializer",
    is  => "ro",
    coerce => 1,
    lazy_build => 1,
);


sub _build_serializer {
    my $self = shift;
    $self->format;
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::DumpFormatter - A role for command line tools that have a
L<KiokuDB::Serializer> object specified using a C<--format> option.

=head1 DESCRIPTION

See L<KiokuDB::Cmd::Command::Dump> for an example.
