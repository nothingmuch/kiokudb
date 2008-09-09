#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Callback;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

has [qw(collapse expand)] => (
    isa => "Str|CodeRef",
    required => 1,
);

sub compile_mappings {
    my ( $self, @args ) = @_;
    return $self->collapse, $self->expand;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
