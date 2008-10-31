#!/usr/bin/perl

package KiokuDB::TypeMap::Default::Passthrough;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Default);

sub _build_datetime_typemap {
    my $self = shift;

    $self->_create_typemap(
        isa_entries => {
            'DateTime' => => {
                type      => 'KiokuDB::TypeMap::Entry::Passthrough',
                intrinsic => 1,
            },
        },
    );
}

sub _build_path_class_typemap {
    my $self = shift;

    $self->_create_typemap(
        isa_entries => {
            'Path::Class::Entity' => {
                type      => "KiokuDB::TypeMap::Entry::Passthrough",
                intrinsic => 1,
            },
        },
    );
}

sub _build_uri_typemap {
    my $self = shift;

    $self->_create_typemap(
        isa_entries => {
            'URI' => {
                type      => "KiokuDB::TypeMap::Entry::Passthrough",
                intrinsic => 1,
            },
        },
        entries => {
            'URI::WithBase' => {
                type      => "KiokuDB::TypeMap::Entry::Passthrough",
                intrinsic => 1,
            },
        },
    );
}

sub _build_authen_passphrase_typemap {
    my $self = shift;

    $self->_create_typemap(
        isa_entries => {
            'Authen::Passphrase' => {
                type      => "KiokuDB::TypeMap::Entry::Passthrough",
                intrinsic => 1,
            },
        },
    );
}

__PACKAGE__

__END__
