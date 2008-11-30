#!/usr/bin/perl

package KiokuDB::LinkChecker::Results;
use Moose;

use Set::Object;

use namespace::clean -except => 'meta';

# Set::Object of 1 million IDs is roughly 100mb of memory == 100 bytes per ID
# no need to scale anything more, if you have that many objects you should
# probably write your own tool
has [qw(seen referenced missing broken)] => (
    isa => "Set::Object",
    is  => "ro",
    default => sub { Set::Object->new },
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
