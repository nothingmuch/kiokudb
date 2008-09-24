#!/usr/bin/perl

package KiokuDB::Set::Transient;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Set);

extends qw(KiokuDB::Set::Base);

sub loaded { 1 }

sub includes { shift->_objects->includes(@_) }
sub remove   { shift->_objects->remove(@_) }
sub insert   { shift->_objects->insert(@_) }
sub members  { shift->_objects->members }

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
