#!/usr/bin/perl

package MooseX::Storage::Directory::Backend::Serialize;
use Moose::Role;

use namespace::clean -except => 'meta';

requires qw(serialize deserialize);

__PACKAGE__

__END__

