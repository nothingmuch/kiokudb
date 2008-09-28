#!/usr/bin/perl

package KiokuDB::Role::UUIDs::DataUUID;
use Moose::Role;

use namespace::clean -except => 'meta';

with join("::", __PACKAGE__, "Str" );

__PACKAGE__

__END__
