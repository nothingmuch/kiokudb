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
            # since Authen::Passphrase dynamically loads subcomponents based on
            # type, passthrough causes issues with the class not being defined
            # at load time unless explicitly loaded by the user.
            # this works around this issue
            #'Authen::Passphrase' => {
            #    type      => "KiokuDB::TypeMap::Entry::Passthrough",
            #    intrinsic => 1,
            #},
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

=pod

=head1 NAME

KiokuDB::TypeMap::Default::Passthrough - A L<KiokuDB::TypeMap::Default>
instance suitable for L<Storable>.

=head1 DESCRIPTION

This typemap lets most of the default data types be passed through untouched,
so that their own L<Storable> hooks may be invoked.
