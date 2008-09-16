#!/usr/bin/perl

package KiokuDB::Backend::Serialize::JSPON::Expander;
use Moose;

use Carp qw(croak);

use KiokuDB::Entry;
use KiokuDB::Reference;

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

# Note: this method is destructive
# maybe it's a good idea to copy $hash before deleting items out of it?
sub expand_jspon {
    my ( $self, $data, @attrs ) = @_;

    my $id = delete $data->{id};

    if ( exists $data->{__CLASS__} ) {
        # check the class more thoroughly here ...
        my ($class, $version, $authority) = (split '-' => delete $data->{__CLASS__});
        push @attrs, class => $class;
    }

    return KiokuDB::Entry->new(
        id   => $id,
        data => $self->visit($data),
        @attrs,
    );
}

sub visit_hash_key {
    my ( $self, $key ) = @_;
    $key =~ s/^public:://x;
    return $key;
}

sub visit_hash {
    my ( $self, $hash ) = @_;

    if ( my $id = $hash->{'$ref'} ) {
        return KiokuDB::Reference->new( id => $id, ( $hash->{weak} ? ( is_weak => 1 ) : () ) );
    } else {
        return $self->SUPER::visit_hash($hash);
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::JSPON::Expander - Inflate JSPON to entry
data.

=cut


