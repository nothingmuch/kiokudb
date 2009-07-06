#!/usr/bin/perl

package KiokuDB::Test::Employee;
use Moose;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Test::Person);

has company => (
    isa => "KiokuDB::Test::Company",
    is  => "rw",
);

sub lalala { 333 }

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
