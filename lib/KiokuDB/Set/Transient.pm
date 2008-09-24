#!/usr/bin/perl

package KiokuDB::Set::Transient;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Set);

has _objects => (
    isa => "Set::Object",
    is  => "ro",
    init_arg => "set",
    required => 1,
);

sub loaded { 1 }

sub clear    { shift->_objects->clear }
sub size     { shift->_objects->size }
sub includes { shift->_objects->includes(@_) }
sub remove   { shift->_objects->remove(@_) }
sub insert   { shift->_objects->insert(@_) }
sub members  { shift->_objects->members }

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
