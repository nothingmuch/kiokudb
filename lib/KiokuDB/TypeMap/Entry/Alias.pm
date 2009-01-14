#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Alias;
use Moose;

use namespace::clean -except => 'meta';

has to => (
    isa => "Str",
    is  => "ro",
    required => 1,
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::Alias - An alias in the typemap to another entry

=head1 SYNOPSIS

    my $typemap = KiokuDB::TypeMap->new(
        entries => {
            'Some::Class' => KiokuDB::TypeMap::Entry::Alias->new(
                to => "Some::Other::Class",
            ),
            'Some::Other::Class' => ...,
        },
    );

=head1 DESCRIPTION

This pseudo-entry directs the typemap resolution to re-resolve with the key in
the C<to> field.
