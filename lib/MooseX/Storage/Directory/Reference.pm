#!/usr/bin/perl

package MooseX::Storage::Directory::Reference;
use Moose;

has id => (
    isa => "Str",
    is  => "rw",
    required => 1,
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::Storage::Directory::Reference - A reference to another
L<MooseX::Storage::Directory::Entry>.

=head1 SYNOPSIS

    my $ref = MooseX::Storage::Directory::Reference->new(
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

=back

=head1 TODO

=over 4

=item *

C<is_weak> attribute

=back

=cut
