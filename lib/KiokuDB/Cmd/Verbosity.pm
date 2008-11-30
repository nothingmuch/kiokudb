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
