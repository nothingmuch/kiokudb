#!/usr/bin/perl

package KiokuDB::Set::Stored;
use Moose;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Set::Base);

has _objects => ( is => "ro" );

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
