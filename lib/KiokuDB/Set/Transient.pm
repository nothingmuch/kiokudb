#!/usr/bin/perl

package KiokuDB::Set::Transient;
use Moose;

use Carp qw(croak);

use namespace::clean -except => 'meta';

with qw(KiokuDB::Set);

extends qw(KiokuDB::Set::Base);

sub loaded { 1 }

sub includes { shift->_objects->includes(@_) }
sub remove   { shift->_objects->remove(@_) }
sub members  { shift->_objects->members }

sub insert   {
    my ( $self, @objects ) = @_;
    croak "Can't insert non reference into a KiokuDB::Set" if grep { not ref } @objects;
    $self->_objects->insert(@objects)
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set::Deferred - Implementation of in memory sets.

=head1 SYNOPSIS

    my $set = KiokuDB::Set::Transient->new(
        set => Set::Object->new( @objects ),
    );

    # or

    use KiokuDB::Util qw(set);

    my $set = set(@objects);

=head1 DESCRIPTION

This class implements sets conforming to the L<KiokuDB::Set> API.

These sets can be constructed by the user for insertion into storage.

See L<KiokuDB::Set> for more details.

=cut

