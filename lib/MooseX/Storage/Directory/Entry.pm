#!/usr/bin/perl

package MooseX::Storage::Directory::Entry;
use Moose;

has id => (
    isa => "Str",
    is  => "ro",
);

has root => (
    isa => "Bool",
    is  => "rw",
    default => 0,
);

has data => (
    isa => "Ref",
    is  => "ro",
);

has class => (
    isa => "Class::MOP::Class",
    is  => "ro",
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::Storage::Directory::Entry - 
