#!/usr/bin/perl

package KiokuDB::Backend::Role::TXN;
use Moose::Role;

use namespace::clean -except => 'meta';

requires qw(txn_begin txn_commit txn_rollback);

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Role::TXN - Backend level transaction support.

=head1 SYNOPSIS

    package MyBackend;
    use Moose;

    with qw(
        KiokuDB::Backend
        KiokuDB::Backend::Role::TXN
    );

    sub txn_begin { ... }
    sub txn_commit { ... }
    sub txn_rollback { ... }

=head1 DESCRIPTION

This API is inspired by standard database transactions much like you get with
L<DBI>.

This is the low level interface required by L<KiokuDB/txn_do>.

=cut
