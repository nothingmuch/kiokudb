#!/usr/bin/perl

package KiokuDB::Cmd::WithDSN;
use Moose::Role;

use namespace::clean -except => 'meta';

has dsn => (
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
