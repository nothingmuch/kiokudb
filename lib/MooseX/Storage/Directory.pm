#!/usr/bin/perl

package MooseX::Storage::Directory;
use Moose;

our $VERSION = "0.01_01";

use MooseX::Storage::Directory::Backend;
use MooseX::Storage::Directory::Resolver;
use MooseX::Storage::Directory::Collapser;
use MooseX::Storage::Directory::Linker;
use MooseX::Storage::Directory::LiveObjects;

use Hash::Util::FieldHash::Compat qw(idhash);

use namespace::clean -except => 'meta';

has live_objects => (
    isa => "MooseX::Storage::Directory::LiveObjects",
    is  => "ro",
    lazy_build => 1,
);

sub _build_live_objects { MooseX::Storage::Directory::LiveObjects->new }

has resolver => (
    isa => "MooseX::Storage::Directory::Resolver",
    is  => "ro",
    lazy_build => 1,
);

sub _build_resolver {
    my $self = shift;

    MooseX::Storage::Directory::Resolver->new(
        live_objects => $self->live_objects,
    );
}

has collapser => (
    isa => "MooseX::Storage::Directory::Collapser",
    is  => "ro",
    lazy_build => 1,
);

sub _build_collapser {
    my $self = shift;

    MooseX::Storage::Directory::Collapser->new(
        resolver => $self->resolver,
    );
}

has backend => (
    does => "MooseX::Storage::Directory::Backend",
    is   => "ro",
    required => 1,
);

has linker => (
    isa => "MooseX::Storage::Directory::Linker",
    is  => "ro",
    lazy_build => 1,
);

sub _build_linker {
    my $self = shift;

    MooseX::Storage::Directory::Linker->new(
        backend => $self->backend,
        live_objects => $self->live_objects,
    );
}

sub lookup {
    my ( $self, @ids ) = @_; # FIXME @ids

    my $linker = $self->linker;

    my @objects = map { $linker->get_or_load_object($_) } @ids;

    if ( @ids == 1 ) {
        return $objects[0];
    } else {
        return @objects;
    }
}

sub search { }

sub scan { }

sub grep { }

sub all { }

sub store {
    my ( $self, @objects ) = @_;

    idhash my %ids;

    @ids{@objects} = $self->live_objects->objects_to_ids(@objects);

    # FIXME update known objects?
    if ( my @unknown = grep { not $ids{$_} } @objects ) {
        my @entries = $self->collapser->collapse_objects(@unknown);
        $self->backend->insert( @entries );
        @ids{@objects} = map { $_->id } @entries[ 0 .. $#objects ];
    }

    if ( @objects == 1 ) {
        return $ids{$objects[0]};
    } else {
        return @ids{@objects};
    }
}

sub delete { }

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::Storage::Directory - The Great New magic data MooseX::Storage::Directory!

=head1 SYNOPSIS

	use MooseX::Storage::Directory;

    my $d = MooseX::Storage::Directory->new(
        backend => MooseX::Storage::Directory::Backend::JSPON->new(
            dir => "/tmp/foo",
        ),
    );

    my $uid = $d->store( $some_object );

    my $some_object = $d->lookup($uid);

=head1 DESCRIPTION



=head1 VERSION CONTROL

L<http://code2.0beta.co.uk/moose/svn/>. Ask on #moose for commit bits.

=head1 AUTHOR

Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>

=head1 COPYRIGHT

	Copyright (c) 2008 Yuval Kogman, Infinity Interactive. All rights
    reserved This program is free software; you can redistribute
	it and/or modify it under the same terms as Perl itself.

=cut
