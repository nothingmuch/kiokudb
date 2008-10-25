#!/usr/bin/perl

package KiokuDB::Set::Stored;
use Moose;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Set::Base);

has _objects => ( is => "ro" );

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set::Stored - Stored representation of L<KiokuDB::Set> objects.

=head1 SYNOPSIS

    # used internally by L<KiokuDB::TypeMap::Entry::Set>

=head1 DESCRIPTION

This object is the persisted representation of all L<KiokuDB::Set> objects.

It is used internall after collapsing and before expanding, for simplicity.

