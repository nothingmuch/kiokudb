#!/usr/bin/perl

package MooseX::Storage::Directory;
use Moose;

our $VERSION = "0.01_01";

# set $BINARY_UUIDS before loading to use string UUIDs in memory (eases
# debugging), while retaining storage compat
# for even easier debugging, $SERIAL_IDs are not UUIDs at all, but this is not
# compatible
our ( $BINARY_UUIDS, $SERIAL_IDS );

use constant SERIAL_IDS           => not not our $SERIAL_IDS;
use constant RUNTIME_BINARY_UUIDS => !SERIAL_IDS && ( defined($BINARY_UUIDS) ? not not $BINARY_UUIDS : 0 );

use MooseX::Storage::Directory::Backend;
use MooseX::Storage::Directory::Resolver;
use MooseX::Storage::Directory::Collapser;
use MooseX::Storage::Directory::Linker;
use MooseX::Storage::Directory::LiveObjects;

use Hash::Util::FieldHash::Compat qw(idhash);
use Carp qw(croak);

use namespace::clean -except => [qw(meta SERIAL_IDS RUNTIME_BINARY_UUIDS)];

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
    my ( $self, @ids ) = @_;

    my $linker = $self->linker;

    my ( $e, @objects );

    eval {
        local $@;
        eval { @objects = $linker->get_or_load_objects(@ids) };
        $e = $@;
    };

    if ( $e ) {
        if ( ref($e) and $e->{missing} ) {
            return;
        }

        use Data::Dumper;
        warn Dumper($e);
        die $e;
    }

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

    $self->store_objects( root_set => 1, objects => \@objects );

}

sub insert {
    my ( $self, @objects ) = @_;

    idhash my %ids;

    @ids{@objects} = $self->live_objects->objects_to_ids(@objects);

    if ( my @unknown = grep { not $ids{$_} } @objects ) {

        $self->store_objects( root_set => 1, objects => \@unknown );

        # return IDs only for unknown objects
        if ( defined wantarray ) {
            idhash my %ret;
            @ret{@unknown} = $self->live_objects->objects_to_ids(@unknown);
            return @ret{@objects};
        }
    }

    return;
}

sub update {
    my ( $self, @objects ) = @_;

    croak "Object not in storage"
        if grep { not defined } $self->live_objects->objects_to_entries(@objects);

    $self->store_objects( shallow => 1, only_known => 1, objects => \@objects );
}

sub store_objects {
    my ( $self, %args ) = @_;

    my $objects = $args{objects};

    my $entries = $self->collapser->collapse(%args); 

    my @ids = $self->live_objects->objects_to_ids(@$objects);

    if ( $args{root_set} ) {
        $_->root(1) for grep { defined } @{$entries}{@ids};
    }

    $self->backend->insert(values %$entries);

    # FIXME update index

    if ( @$objects == 1 ) {
        return $ids[0];
    } else {
        return @ids;
    }
}

sub delete {
    my ( $self, @objects ) = @_;

    my @ids_or_entries = (
        $self->live_objects->objects_to_entries(grep { ref } @objects),
        grep { not ref } @objects,
    );

    for ( @ids_or_entries ) {
        croak "Object not in storage" unless defined;
    }

    $self->backend->delete(@ids_or_entries);
}

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
