#!/usr/bin/perl

package KiokuDB::Set::Storage;
use Moose::Role;

use Set::Object;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Set);

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set::Storage - Role for L<KiokuDB::Set>s that are tied to storage.

=head1 SYNOPSIS

    # informational role, used internally

=head1 DESCRIPTION

This role is informational, and implemented by L<KiokuDB::Set::Deferred> and
L<KiokuDB::Set::Loaded>

=cut
