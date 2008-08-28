#!/usr/bin/perl

package KiokuDB::Reference;
use Moose;

has id => (
    isa => "Str",
    is  => "rw",
    required => 1,
);

has is_weak => (
    isa => "Bool",
    is  => "rw",
);

sub STORABLE_freeze {
    my ( $self, $cloning ) = @_;


    join(",", $self->id, !!$self->is_weak);
}

sub STORABLE_thaw {
    my ( $self, $cloning, $serialized ) = @_;
    my ( $id, $weak ) = split ',', $serialized;

    $self->id($id);
    $self->is_weak(1) if $weak;

    return $self;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Reference - A symbolic reference to another L<KiokuDB::Entry>.

=head1 SYNOPSIS

    my $ref = KiokuDB::Reference->new(
        id => $some_id,
    );

=head1 DESCRIPTION

This object serves as an internal marker to point to entries by UID.

The linker resolves these references by searching the live object set and
loading entries from the backend as necessary.

=head1 ATTRIBUTES

=over 4

=item id

The ID this entry refers to

=item is_weak

This reference is weak.

=back

=cut
