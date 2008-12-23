#!/usr/bin/perl

package KiokuDB::Cmd::DumpFormatter;
use Moose::Role;

use Moose::Util::TypeConstraints;

use KiokuDB::Serializer;

use namespace::clean -except => 'meta';

has format => (
    isa => enum([qw(yaml json storable)]),
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
