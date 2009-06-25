#!/usr/bin/perl

package KiokuDB::TypeMap::Default::JSON;
use Moose;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::TypeMap);

with 'KiokuDB::TypeMap::Default::Canonical' => {
    excludes => [qw(reftype_entries)],
};

has json_boolean_typemap => (
    traits     => [qw(KiokuDB::TypeMap)],
    does       => "KiokuDB::Role::TypeMap",
    is         => "ro",
    lazy_build => 1,
);

sub reftype_entries {
    my $self = shift;

    return (
        $self->KiokuDB::TypeMap::Default::Canonical::reftype_entries,
        SCALAR => "KiokuDB::TypeMap::Entry::JSON::Scalar",
    );
}

sub _build_json_boolean_typemap {
    my $self = shift;

    $self->_create_typemap(
        isa_entries => {
            'JSON::Boolean' => {
                type      => "KiokuDB::TypeMap::Entry::Passthrough",
                intrinsic => 1,
            },
        },
    );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
