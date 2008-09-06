#!/usr/bin/perl

package KiokuDB::Test::Company;
use Moose;

use namespace::clean -except => 'meta';

use MooseX::Storage;

with Storage(format => "JSON", io => "File" );

has name => (
    isa => "Str",
    is  => "rw",
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
