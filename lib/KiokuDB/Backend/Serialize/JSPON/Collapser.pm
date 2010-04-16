#!/usr/bin/perl

package KiokuDB::Backend::Serialize::JSPON::Collapser;
use Moose;

use KiokuDB::Entry;
use KiokuDB::Reference;
use JSON;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Backend::Serialize::JSPON::Converter);

has reserved_key => (
    isa => "RegexpRef",
    is  => "ro",
    lazy_build => 1,
);

sub _build_reserved_key {
    my $self = shift;

    my $reserved = '^(?:' . join("|", map { quotemeta($self->$_) } map { $_ . "_field" } $self->_jspon_fields) . ')$';

    qr/(?: $reserved | ^public:: )/x
}

sub collapse_jspon {
    my ( $self, $data ) = @_;

    if ( my $ref = ref $data ) {
        if ( $ref eq 'KiokuDB::Reference' ) {
            return {
                $self->ref_field => $data->id . ( $self->inline_data ? "" : "." . $self->data_field ),
                ( $data->is_weak ? ( weak => 1 ) : () ),
            };
        } elsif ( $ref eq 'KiokuDB::Entry' ) {
            my $id = $data->id;

            return {
                ( $data->has_class ? ( $self->class_field => $data->class ) : () ),
                ( $data->has_class_meta ? ( $self->class_meta_field => $data->class_meta ) : () ),
                ( $id ? ( $self->id_field => $id ) : () ),
                ( $data->root ? ( $self->root_field => JSON::true() ) : () ),
                ( $data->deleted ? ( $self->deleted_field => JSON::true() ) : () ),
                ( $data->has_tied ? ( $self->tied_field => $data->tied ) : () ),
                ( $self->inline_data
                    ? %{ $self->collapse_jspon($data->data) }
                    : ( $self->data_field => $self->collapse_jspon($data->data) )
                ),
            };
        } elsif ( $ref eq 'HASH' ) {
            my %hash;
            my $res = $self->reserved_key;

            foreach my $key ( keys %$data ) {
                my $value = $data->{$key};
                my $collapsed = ref($value) ? $self->collapse_jspon($value) : $value;

                if ( $key =~ $res ) {
                    $hash{"public::$key"} = $collapsed;
                } else {
                    $hash{$key} = $collapsed;
                }
            }

            return \%hash;
        } elsif ( $ref eq 'ARRAY' ) {
            return [ map { ref($_) ? $self->collapse_jspon($_) : $_ } @$data ];
        }
    }

    return $data;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Serialize::JSPON::Collapser - Collapse entry data to
JSPON compliant structures

=head1 SYNOPSIS

    my $c = KiokuDB::Backend::Serialize::JSPON::Collapser->new(
        id_field => "_id",
    );

    my $hashref = $c->collapse_jspon($entry);

=head1 DESCRIPTION

This object is used by L<KiokuDB::Backend::Serialize::JSPON> to convert
L<KiokuDB::Entry> objects to JSPON compliant structures.

=head1 ATTRIBUTES

See L<KiokuDB::Backend::Serialize::JSPON::Converter> for attributes shared by
L<KiokuDB::Backend::Serialize::JSPON::Collapser> and
L<KiokuDB::Backend::Serialize::JSPON::Expander>.

=head1 METHODS

=over 4

=item collapse_jspon $entry

Collapses the entry recursively, returning a JSPON compliant data structure
suitable for serialization as a JSON string.

=back

=cut

