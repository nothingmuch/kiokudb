#!/usr/bin/perl

package KiokuDB::TypeMap::Default::Canonical;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Default);

sub _build_path_class_typemap {
    my $self = shift;

    $self->_create_typemap(
        isa_entries => {
            'Path::Class::Entity' => {
                type      => "KiokuDB::TypeMap::Entry::Callback",
                intrinsic => 1,
                collapse  => "stringify",
                expand    => "new",
            },
        },
    );
}

sub _build_uri_typemap {
    my $self = shift;

    $self->_create_typemap(
        isa_entries => {
            'URI' => {
                type      => "KiokuDB::TypeMap::Entry::Callback",
                intrinsic => 1,
                collapse  => 'as_string',
                expand    => "new",
            },
        },
        entries => {
            'URI::WithBase' => {
                type      => "KiokuDB::TypeMap::Entry::Naive",
                intrinsic => 1,
            },
        },
    );
}

sub _build_datetime_typemap {
    my $self = shift;

    $self->_create_typemap(
        isa_entries => {
            'DateTime' => => {
                type      => 'KiokuDB::TypeMap::Entry::Callback',
                collapse  => "iso8601",
                expand    => sub {
                    my ( $class, $datetime ) = @_;
                    DateTime::Format::ISO8601->parse_datetime($datetime);
                },
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
                type      => "KiokuDB::TypeMap::Entry::Callback",
                intrinsic => 1,
                collapse  => "as_rfc2307",
                expand    => "from_rfc2307",
            },
        },
    );
}

__PACKAGE__

__END__
