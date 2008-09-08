#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Naive;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

sub compile_mappings {
    my ( $self, @args ) = @_;
    return qw(collapse_naive expand_naive);
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
