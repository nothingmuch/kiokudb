#!/usr/bin/perl

package KiokuDB::Set::Stored;
use Moose;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Set::Base);

has _objects => ( is => "ro" );

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set::Stored - 

=head1 SYNOPSIS

	use KiokuDB::Set::Stored;

=head1 DESCRIPTION

=cut


