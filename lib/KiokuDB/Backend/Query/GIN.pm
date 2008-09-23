#!/usr/bin/perl

package KiokuDB::Backend::Query::GIN;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(
    Search::GIN::Driver
    Search::GIN::Extract::Delegate
);

__PACKAGE__

__END__
