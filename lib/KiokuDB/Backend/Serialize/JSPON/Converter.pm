#!/usr/bin/perl

package KiokuDB::Backend::Serialize::JSPON::Converter;
use Moose::Role;

use namespace::clean -except => 'meta';

has id_field => (
    isa => "Str",
    is  => "ro",
    default => "id",
);

has class_field => (
    isa => "Str",
    is  => "ro",
    default => "__CLASS__",
);

has root_field => (
    isa => "Str",
    is  => "ro",
    default => "root",
);

has deleted_field => (
    isa => "Str",
    is  => "ro",
    default => "deleted",
);

has tied_field => (
    isa => "Str",
    is  => "ro",
    default => "tied",
);

has ref_field => (
    isa => "Str",
    is  => "ro",
    default => '$ref',
);

has data_field => (
    isa => "Str",
    is  => "ro",
    default => "data",
);

has inline_data => (
    isa => "Bool",
    is  => "ro",
    default => 0,
);

# kinda ugly, used to pass options down to expander/collapser from backend
has _jspon_params => (
    isa => "HashRef",
    is  => "ro",
    lazy_build => 1,
);

sub _build__jspon_params {
    my $self = shift;

    return {
        ( map {
            my $name = "${_}_field";
            $name => $self->$name
        } qw(id class root deleted tied ref data) ),
        ( inline_data => $self->inline_data ? 1 : 0 ),
    };
}

__PACKAGE__

__END__


