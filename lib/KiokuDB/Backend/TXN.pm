#!/usr/bin/perl

package KiokuDB::Backend::TXN;
use Moose::Role;

use namespace::clean -except => 'meta';

requires qw(txn_begin txn_commit txn_rollback);

__PACKAGE__

__END__
