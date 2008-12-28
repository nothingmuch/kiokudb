#!/usr/bin/perl

package KiokuDB::Cmd::WithDSN::Create;
use Moose::Role;

use Carp qw(croak);

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Cmd::WithDSN
    KiokuDB::Cmd::TXN
);

requires "v";

has clear => (
    isa => "Bool",
    is  => "ro",
    cmd_aliases => "x",
    documentation => "clear the database before loading",
);

has create => (
    isa => "Bool",
    is  => "ro",
    default => 1,
    cmd_aliases => "c",
    documentation => "create the database if it doesn't exist (defaults to true)",
);

sub _build_backend {
    my $self = shift;

    my $dsn = $self->dsn || croak("--dsn is required");

    $self->v("Connecting to DSN $dsn...");

    require KiokuDB::Util;
    my $b = KiokuDB::Util::dsn_to_backend( $dsn, create => $self->create );

    $self->v(" $b\n");

    $self->try_txn_begin($b);

    if ( $self->clear ) {
        unless ( $b->does("KiokuDB::Backend::Role::Clear") ) {
            croak "--clear specified but $b does not support clearing";

        }
        $self->v("clearing database....");

        $b->clear;

        $self->v(" done\n");

    }

    $b;
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::WithDSN::Create - Write or create access to a DSN for command
line tools

=head1 SYNOPSIS

    package KiokuDB::Cmd::Command::Blort;
    use Moose;

    extends qw(KiokuDB::Cmd::Base);

    with qw(KiokuDB::Cmd::WithDSN::Create);

    augment run => sub {
        my $self = shift;

        $self->backend;
    };

=head1 ATTRIBUTES

=over 4

=item dsn

Command line attr for the DSN to connect to.

=item create

A boolean determining whether the C<create> flag is passed to C<connect>.
Defaults to true but can be disabled (C<--nocreate>).

=item clear

Command line attr determining whether or not C<clear> will be called on the
backend. Defaults to false.

=item backend

Non command line attr, contains the composed backend.

=back
