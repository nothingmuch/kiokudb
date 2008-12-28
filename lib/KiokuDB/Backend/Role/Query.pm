#!/usr/bin/perl

package KiokuDB::Backend::Role::Query;
use Moose::Role;

use namespace::clean -except => 'meta';

requires "search";

sub search_filter {
    my ( $self, $stream, @args ) = @_;
    return $stream;
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Role::Query - Backend specific query API

=head1 SYNOPSIS

    with qw(KiokuDB::Backend::Role::Query);

    sub search {
        my ( $self, @args ) = @_;

        # return all entries in the root set matching @args (backend specific)
        return Data::Stream::Bulk::Foo->new(...);
    }

=head1 DESCRIPTION

This role is for backend specific searching. Anything that is not
L<KiokuDB::Backend::Role::Query::Simple> is a backend specific search, be it a
L<Search::GIN::Query>, or something else.

The backend is expected to interpret the search arguments which are passed
through from L<KiokuDB/search> as is, and return a L<Data::Stream::Bulk> of
matching entries.

=cut


