#!/usr/bin/perl

package KiokuDB::Backend::Serialize::JSPON::Expander;
use Moose;

use Carp qw(croak);

use KiokuDB::Entry;
use KiokuDB::Reference;

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

with qw(KiokuDB::Backend::Serialize::JSPON::Converter);

# Note: this method is destructive
# maybe it's a good idea to copy $hash before deleting items out of it?
sub expand_jspon {
    my ( $self, $data, @attrs ) = @_;

    my %copy = %$data;

    my $class_field = $self->class_field;

    if ( exists $copy{$class_field} ) {
        # check the class more thoroughly here ...
        my ($class, $version, $authority) = (split '-' => delete $copy{$class_field});
        push @attrs, class => $class;

        push @attrs, class_meta => delete $copy{$self->class_meta_field} if exists $copy{$self->class_meta_field};
    }

    push @attrs, id      => delete $copy{$self->id_field} if exists $copy{$self->id_field};
    push @attrs, tied    => delete $copy{$self->tied_field} if exists $copy{$self->tied_field};
    push @attrs, root    => delete $copy{$self->root_field} ? 1 : 0 if exists $copy{$self->root_field};
    push @attrs, deleted => delete $copy{$self->deleted_field} ? 1 : 0 if exists $copy{$self->deleted_field};

    push @attrs, data => $self->visit( $self->inline_data ? \%copy : $copy{$self->data_field} );

    return KiokuDB::Entry->new( @attrs );
}

sub visit_hash_key {
    my ( $self, $key ) = @_;
    $key =~ s/^public:://x;
    return $key;
}

sub visit_hash {
    my ( $self, $hash ) = @_;

    if ( my $id = $hash->{$self->ref_field} ) {
        $id =~ s/\.data$// unless $self->inline_data;
        return KiokuDB::Reference->new( id => $id, ( $hash->{weak} ? ( is_weak => 1 ) : () ) );
    } else {
        if ( exists $hash->{$self->class_field}
          or exists $hash->{$self->id_field}
          or exists $hash->{$self->tied_field}
        ) {
            return $self->expand_jspon($hash);
        } else {
            return $self->SUPER::visit_hash($hash);
        }
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Serialize::JSPON::Expander - Inflate JSPON to entry
data.

=head1 SYNOPSIS

    my $c = KiokuDB::Backend::Serialize::JSPON::Expander->new(
        id_field => "_id",
    );

    my $entry = $c->collapse_jspon($hashref);

=head1 DESCRIPTION

This object is used by L<KiokuDB::Backend::Serialize::JSPON> to expand JSPON
compliant hash references to L<KiokuDB::Entry> objects.

=head1 ATTRIBUTES

See L<KiokuDB::Backend::Serialize::JSPON::Converter> for attributes shared by
L<KiokuDB::Backend::Serialize::JSPON::Collapser> and
L<KiokuDB::Backend::Serialize::JSPON::Expander>.

=head1 METHODS

=over 4

=item expand_jspon $hashref

Recursively inlates the hash reference, returning a L<KiokuDB::Entry> object.

=back
