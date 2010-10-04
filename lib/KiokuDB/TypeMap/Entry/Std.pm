#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Std;
use Moose::Role;

use KiokuDB::TypeMap::Entry::Compiled;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::TypeMap::Entry
    KiokuDB::TypeMap::Entry::Std::ID
    KiokuDB::TypeMap::Entry::Std::Compile
    KiokuDB::TypeMap::Entry::Std::Intrinsic
);


__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::Std - Role for more easily specifying collapse/expand methods

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

This role just integrates other roles into a single place for convenience.  The roles
that it integrates are:

=over 4

=item KiokuDB::TypeMap::Entry

=item KiokuDB::TypeMap::Entry::Std::ID

=item KiokuDB::TypeMap::Entry::Std::Compile

=item KiokuDB::TypeMap::Entry::Std::Intrinsic

=back

=head1 SEE ALSO

L<KiokuDB::TypeMap::Entry>
L<KiokuDB::TypeMap::Entry::Std::ID>
L<KiokuDB::TypeMap::Entry::Std::Compile>
L<KiokuDB::TypeMap::Entry::Std::Intrinsic>

=cut
