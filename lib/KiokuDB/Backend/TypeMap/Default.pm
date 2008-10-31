#!/usr/bin/perl

package KiokuDB::Backend::TypeMap::Default;
use Moose::Role;

use namespace::clean -except => 'meta';

has default_typemap => (
    does => "KiokuDB::Role::TypeMap",
    is   => "ro",
    required   => 1,
    lazy_build => 1,
);

requires "_build_default_typemap";

__PACKAGE__

__END__
