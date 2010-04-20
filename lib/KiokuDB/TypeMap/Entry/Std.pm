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
