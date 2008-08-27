#!/usr/bin/perl

package KiokuDB::Backend::Serialize;
use Moose::Role;

use namespace::clean -except => 'meta';

requires qw(serialize deserialize);

__PACKAGE__

__END__

