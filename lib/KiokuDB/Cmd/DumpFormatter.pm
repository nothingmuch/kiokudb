#!/usr/bin/perl

package KiokuDB::Cmd::DumpFormatter;
use Moose::Role;

use Moose::Util::TypeConstraints;

use namespace::clean -except => 'meta';

has format => (
    isa => enum([qw(yaml json storable)]),
    is  => "ro",
    default => "yaml",
    cmd_aliases => "f",
    documentation => "dump format ('yaml', 'storable', etc)"
);

has formatter => (
    traits => [qw(NoGetopt EarlyBuild)],
    isa => "CodeRef",
    is  => "ro",
    lazy_build => 1,
);

requires '_build_formatter';

__PACKAGE__

__END__
