#!/usr/bin/perl

package KiokuDB::Backend::Null;
use Moose;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend
);

sub insert { return }

sub get { return }

sub delete { return }

sub exists { return }

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

