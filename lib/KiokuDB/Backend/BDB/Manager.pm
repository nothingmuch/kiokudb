#!/usr/bin/perl

package KiokuDB::Backend::BDB::Manager;
use Moose;

use Moose::Util::TypeConstraints;

use namespace::clean -except => 'meta';

extends "BerkeleyDB::Manager";

has '+home' => ( required => 1 );

has '+data_dir' => ( default => "data" );

has '+log_dir' => ( default => "logs" );

coerce( __PACKAGE__,
    from HashRef => via { __PACKAGE__->new(%$_) },
    from Str     => via { __PACKAGE__->new( home => $_ ) },
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::BDB::Manager - 

=head1 SYNOPSIS

	use KiokuDB::Backend::BDB::Manager;

=head1 DESCRIPTION

=cut


