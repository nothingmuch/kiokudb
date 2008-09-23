#!/usr/bin/perl

package KiokuDB::Backend::Query::GIN;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(
    Search::GIN::Extract
    Search::GIN::Driver
);

has distinct => (
    isa => "Bool",
    is  => "rw",
    default => 0, # FIXME what should the default be?
);

sub search {
    my ( $self, $query, @args ) = @_;

    my %args = (
        distinct => $self->distinct,
        @args,
    );

    my @spec = $query->extract_values($self);

    my $ids = $self->fetch_entries(@spec);

    $ids = unique($ids) if $args{distinct};

    return $ids->filter(sub {[ $self->get(@$_) ]});
}

sub search_filter {
    my ( $self, $objects, $query, @args ) = @_;
    return $objects->filter(sub { [ grep { $query->consistent($self, $_) } @$_ ] });
}

__PACKAGE__

__END__
