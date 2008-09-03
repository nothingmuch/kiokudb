#!/usr/bin/perl

package KiokuDB::Backend::Query::Simple;
use Moose::Role;

use namespace::clean -except => 'meta';

requires "simple_search";

sub simple_search_filter {
    my ( $self, $stream, $proto ) = @_;
    return $stream;
}

# FIXME unify with Attribute, and put this in the default simple_search_filter
# implementation
# that way *really* lazy backends can just alias simple_search to scan and
# still be feature complete even if they are retardedly slow

sub compare_naive {
    my ( $self, $got, $exp ) = @_;

    foreach my $key ( keys %$exp ) {
        return unless overload::StrVal($got->{$key}) eq overload::StrVal($exp->{$key});
    }

    return 1;
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Query::Simple - Simple query api

=head1 SYNOPSIS

	with qw(KiokuDB::Backend::Query::Simple);

    sub simple_search {
        my ( $self, $proto ) = @_;

        # return all candidate entries in the root set matching fields in $proto
        return Data::Stream::Bulk::Foo->new(...);
    }

=head1 DESCRIPTION

=cut


