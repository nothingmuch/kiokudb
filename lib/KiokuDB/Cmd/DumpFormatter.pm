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


sub _build_formatter {
    my $self = shift;
    my $builder = "_build_formatter_" . $self->format;
    $self->$builder;
}

requires '_build_formatter_yaml';
requires '_build_formatter_storable';
requires '_build_formatter_json';

__PACKAGE__

__END__
