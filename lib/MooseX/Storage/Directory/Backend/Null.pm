#!/usr/bin/perl

package MooseX::Storage::Directory::Backend::Null;
use Moose;

use MooseX::Storage::Directory ();


use namespace::clean -except => 'meta';

with qw(
    MooseX::Storage::Directory::Backend
);

sub insert { return }

sub get { return }

sub delete { return }

sub exists { return }

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
