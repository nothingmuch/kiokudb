#!/usr/bin/perl

package MooseX::Storage::Directory::Backend::Serialize::JSPON;
use Moose::Role;

use MooseX::Storage::Directory::Backend::Serialize::JSPON::Expander;
use MooseX::Storage::Directory::Backend::Serialize::JSPON::Collapser;

use namespace::clean -except => 'meta';

has expander => (
    isa => "MooseX::Storage::Directory::Backend::Serialize::JSPON::Expander",
    is  => "rw",
    lazy_build => 1,
    handles => [qw(expand_jspon)],
);

sub _build_expander {
    my $self = shift;
    MooseX::Storage::Directory::Backend::Serialize::JSPON::Expander->new(
        binary_uuids => $self->binary_uuids,
    );
}

has collapser => (
    isa => "MooseX::Storage::Directory::Backend::Serialize::JSPON::Collapser",
    is  => "rw",
    lazy_build => 1,
    handles => [qw(collapse_jspon)],
);

sub _build_collapser {
    my $self = shift;
    MooseX::Storage::Directory::Backend::Serialize::JSPON::Collapser->new(
        binary_uuids => $self->binary_uuids,
    );
}

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::Storage::Directory::Backend::Serialize::JSPON - 

=head1 SYNOPSIS

	with qw(MooseX::Storage::Directory::Backend::Serialize::JSPON);

=head1 DESCRIPTION

=cut


