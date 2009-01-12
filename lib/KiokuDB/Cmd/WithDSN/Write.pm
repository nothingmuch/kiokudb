#!/usr/bin/perl

package KiokuDB::Cmd::WithDSN::Write;
use Moose::Role;

use Carp qw(croak);

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Cmd::WithDSN
    KiokuDB::Cmd::TXN
);

requires "v";

has dry_run => (
    traits => [qw(Getopt)],
    isa => "Bool",
    is  => "ro",
    cmd_flag => "dry-run",
    cmd_aliases => "n",
    documentation => "don't modify the database",
);

sub _build_backend {
    my $self = shift;

    my $dsn = $self->dsn || croak("--dsn is required");

    $self->v("Connecting to DSN $dsn...");

    require KiokuDB::Util;

    my $b = KiokuDB::Util::dsn_to_backend( $dsn, $self->dry_run ? ( readonly => 1 ) : () );

    $self->v(" $b\n");

    $self->try_txn_begin($b) unless $self->dry_run;

    $b;
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::WithDSN::Write - Read/write access to a DSN

=head1 SYNOPSIS

    package KiokuDB::Cmd::Command::Blort;
    use Moose;

    extends qw(KiokuDB::Cmd::Base);

    with qw(KiokuDB::Cmd::WithDSN::Write);

    augment run => sub {
        my $self = shift;

        $self->backend;
    };

=head1 DESCRIPTION

This role provides normal access to a database.

=head1 ATTRIBUTES

=over 4

=item dsn

Command line attr.

=item backend

Contains the composed connection.

=back
