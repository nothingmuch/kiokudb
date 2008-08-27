#!/usr/bin/perl

package KiokuDB::Backend;
use Moose::Role;

requires qw(
    exists
    insert
    get
    delete
);

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend - Backend interface role

=cut


