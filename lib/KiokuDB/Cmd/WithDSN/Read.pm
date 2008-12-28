#!/usr/bin/perl

package KiokuDB::Cmd::WithDSN::Read;
use Moose::Role;

use Carp qw(croak);

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Cmd::WithDSN
);

requires "v";

sub _build_backend {
    my $self = shift;

    my $dsn = $self->dsn || croak("--dsn is required");

    $self->v("Connecting to DSN $dsn...");

    require KiokuDB::Util;
    my $b = KiokuDB::Util::dsn_to_backend( $dsn, readonly => 1 );

    $self->v(" $b\n");

    $b;
}

__PACKAGE__

__END__
