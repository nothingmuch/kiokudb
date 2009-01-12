#!/usr/bin/perl

package KiokuDB::Role::Immutable;
use Moose::Role;

use namespace::clean -except => 'meta';



__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Role::Immutable - A role for objects that are never updated.

=head1 SYNOPSIS

    with qw(KiokuDB::Role::Immutable);

=head1 DESCRIPTION

This is a role for objects that are never updated after they are inserted to
the database.

The object will be skipped entirely on all update/store operations unless it is
being collapsed for the first time, and its child objects will B<not> be
updated unless they are found while collapsing another object.

This means that:

    my $immutable = $kiokudb->lookup($id);

    $immutable->child->name("foo");

    $kiokudb->update($immutable);

will not work, you need to update the child directly:

    $kiokudb->update($immutable->child);

=cut


