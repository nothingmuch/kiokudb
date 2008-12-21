#!/usr/bin/perl

package KiokuDB::Backend::Serialize::JSON;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::Serialize::JSPON
);

has pretty => (
    isa => "Bool",
    is  => "rw",
    default => 0,
);

has json => (
    isa => "Object",
    is  => "rw",
    lazy_build => 1,
    handles => [qw(encode decode)],
);

sub _build_json {
    my $self = shift;
    my $json = JSON->new->canonical;
    $json->pretty if $self->pretty;
    return $json;
}

sub serialize {
    my ( $self, @args ) = @_;
    $self->encode( $self->collapse_jspon(@args) );
}

sub deserialize {
    my ( $self, $json, @args ) = @_;
    $self->expand_jspon( $self->decode($json), @args );
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Serialize::JSON - Role to serialize entries to JSON strings
with L<KiokuDB::Backend::Serialize::JSPON> semantics

=head1 SYNOPSIS

	with qw(KiokuDB::Backend::Serialize::JSON);

    sub foo {
        my ( $self, $entry ) = @_;

        my $json_string = $self->serialize($entry);
    }

=head1 DESCRIPTION

This role provides additional convenience attributes and methods for backends
that encode entries to JSON strings, on top of
L<KiokuDB::Backend::Serialize::JSPON> which only restructures the data.

=head1 METHODS

=over 4

=item serialize $entry

Returns a JSON string

=item deserialize $json_str

Returns a L<KiokuDB::Entry>

=back

=head1 ATTRIBUTES

=over 4

=item json

The L<JSON> instance used to encode/decode the JSON.

=item pretty

Whether or not to pass the C<pretty> flag to the L<JSON> object after
construction.

=back

=cut


