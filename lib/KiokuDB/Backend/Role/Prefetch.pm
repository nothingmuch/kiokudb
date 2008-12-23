#!/usr/bin/perl

package KiokuDB::Backend::Role::Prefetch;
use Moose::Role;

use namespace::clean -except => 'meta';

requires 'prefetch';

__PACKAGE__

__END__
