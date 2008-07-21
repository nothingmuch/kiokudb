#!/usr/bin/perl

package MooseX::Storage::Directory::Backend;
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

MooseX::Storage::Directory::Backend - Backend interface role

=cut


