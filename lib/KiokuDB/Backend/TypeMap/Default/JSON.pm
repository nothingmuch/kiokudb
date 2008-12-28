#!/usr/bin/perl

package KiokuDB::Backend::TypeMap::Default::JSON;
use Moose::Role;

use KiokuDB::TypeMap::Default::JSON;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Backend::TypeMap::Default);

sub _build_default_typemap {
    # FIXME options
    KiokuDB::TypeMap::Default::JSON->new
}

__PACKAGE__

__END__

