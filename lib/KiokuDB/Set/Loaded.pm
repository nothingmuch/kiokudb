#!/usr/bin/perl

package KiokuDB::Set::Loaded;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Set::Storage);

extends qw(KiokuDB::Set::Base);

sub loaded { 1 }

sub includes { shift->_objects->includes(@_) }
sub remove   { shift->_objects->remove(@_) }
sub insert   { shift->_objects->insert(@_) }
sub members  { shift->_objects->members }

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set::Loaded - 

=head1 SYNOPSIS

	use KiokuDB::Set::Loaded;

=head1 DESCRIPTION

=cut


