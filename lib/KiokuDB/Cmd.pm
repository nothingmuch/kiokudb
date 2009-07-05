#!/usr/bin/perl

package KiokuDB::Cmd;
use Moose;

use KiokuDB;

use namespace::clean -except => 'meta';

extends qw(MooseX::App::Cmd);

our $VERSION = "0.01";
our $KIOKUDB_VERSION = "0.29";

sub is_up_to_date {
    KiokuDB->VERSION($KIOKUDB_VERSION);

    return unless KiokuDB->cmd_is_up_to_date;

    return 1;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd - L<KiokuDB> command line tools

=head1 SYNOPSIS

    # list commnads
    % kioku commands

    # help for a specific command
    % kioku help foo

=head1 DESCRIPTION

This is an L<App::Cmd> based, pluggable suite of commands for L<KiokuDB>.

Some commands such as L<KiokuDB::Cmd::Command::Dump> are part of the core distributions,
but backends can provide their own subcommands as well.

=cut

