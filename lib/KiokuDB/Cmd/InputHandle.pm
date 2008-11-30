#!/usr/bin/perl

package KiokuDB::Cmd::InputHandle;
use Moose::Role;

use MooseX::Types::Path::Class qw(File);

use namespace::clean -except => 'meta';

excludes qw(KiokuDB::Cmd::OutputHandle);

has file => (
    isa => File,
    is  => "ro",
    coerce => 1,
    predicate => "has_file",
    cmd_aliases => "i",
    documentation => "input file (defaults to STDIN)",
);

has input_handle => (
    traits => [qw(NoGetopt EarlyBuild)],
    isa => "FileHandle",
    is  => "ro",
    lazy_build => 1,
);

sub _build_input_handle {
    my $self = shift;

    if ( $self->has_file ) {
        $self->file->openr;
    } else {
        \*STDIN;
    }
}

__PACKAGE__

__END__
