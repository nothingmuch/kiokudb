#!/usr/bin/perl

package KiokuDB::Backend::TypeMap::Default::Storable;
use Moose::Role;

use KiokuDB::TypeMap::Default::Storable;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Backend::TypeMap::Default);

sub _build_default_typemap {
    # FIXME options
    KiokuDB::TypeMap::Default::Storable->new
}

__PACKAGE__

__END__
