#!/usr/bin/perl

package KiokuDB::Backend::Query;
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

KiokuDB::Backend::Query - Backend specific query API

=head1 SYNOPSIS

    with qw(KiokuDB::Backend::Query);

    sub search {
        my ( $self, @args ) = @_;

        # return all entries in the root set matching @args (backend specific)
        return Data::Stream::Bulk::Foo->new(...);
    }

=head1 DESCRIPTION

=cut


