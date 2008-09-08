#!/usr/bin/perl

package KiokuDB;
use Moose;

our $VERSION = "0.01_01";

our ( $BINARY_UUIDS, $SERIAL_IDS );

use constant SERIAL_IDS           => not not our $SERIAL_IDS;
use constant RUNTIME_BINARY_UUIDS => !SERIAL_IDS && ( defined($BINARY_UUIDS) ? not not $BINARY_UUIDS : 0 );

use KiokuDB::Backend;
use KiokuDB::Resolver;
use KiokuDB::Collapser;
use KiokuDB::Linker;
use KiokuDB::LiveObjects;
use KiokuDB::TypeMap;
use KiokuDB::TypeMap::Resolver;

use Hash::Util::FieldHash::Compat qw(idhash);
use Carp qw(croak);

use namespace::clean -except => [qw(meta SERIAL_IDS RUNTIME_BINARY_UUIDS)];

has typemap => (
    isa => "KiokuDB::TypeMap",
    is  => "ro",
    lazy_build => 1,
);

sub _build_typemap {
    KiokuDB::TypeMap->new;
}

has typemap_resolver => (
    isa => "KiokuDB::TypeMap::Resolver",
    is  => "ro",
    lazy_build => 1,
);

sub _build_typemap_resolver {
    my $self = shift;
    KiokuDB::TypeMap::Resolver->new(
        typemap => $self->typemap,
    );
}

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    lazy => 1,
    builder => "_build_live_objects", # lazy_build => 1 sets clearer
    handles => { clear_live_objects => "clear" },
);

sub _build_live_objects { KiokuDB::LiveObjects->new }

has resolver => (
    isa => "KiokuDB::Resolver",
    is  => "ro",
    lazy_build => 1,
);

sub _build_resolver {
    my $self = shift;

    KiokuDB::Resolver->new(
        live_objects => $self->live_objects,
    );
}

has collapser => (
    isa => "KiokuDB::Collapser",
    is  => "ro",
    lazy_build => 1,
);

sub _build_collapser {
    my $self = shift;

    KiokuDB::Collapser->new(
        resolver => $self->resolver,
        typemap_resolver => $self->typemap_resolver,
    );
}

has backend => (
    does => "KiokuDB::Backend",
    is   => "ro",
    required => 1,
    handles => [qw(exists)],
);

has linker => (
    isa => "KiokuDB::Linker",
    is  => "ro",
    lazy_build => 1,
);

sub _build_linker {
    my $self = shift;

    KiokuDB::Linker->new(
        backend => $self->backend,
        live_objects => $self->live_objects,
        typemap_resolver => $self->typemap_resolver,
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

        die $e;
    }

    if ( @ids == 1 ) {
        return $objects[0];
    } else {
        return @objects;
    }
}

sub search {
    my ( $self, @args ) = @_;

    if ( @args == 1 && ref $args[0] eq 'HASH' ) {
        return $self->simple_search(@args);
    } else {
        return $self->backend_search(@args);
    }
}

sub simple_search {

}

sub backend_search {

}

sub root_set {
    my ( $self ) = @_;

    my $stream = $self->backend->root_set;

    $stream->filter(sub { [ grep { ref } $self->lookup(@$_) ] }); # grep ref is in case a scan  or something deleted an ID in a prev page
}

# FIXME remove?
sub all {
    my $self = shift;

    my $root_set = $self->root_set;

    if ( wantarray ) {
        return $root_set->all;
    } else {
        return $root_set;
    }
}

sub grep {
    my ( $self, $filter ) = @_;

    my $stream = $self->root_set;

    $stream->filter(sub { [ grep { $filter->($_) } @$_ ] });
}

sub scan {
    my ( $self, $filter ) = @_;

    my $stream = $self->root_set;

    while ( my $items = $stream->next ) {
        foreach my $item ( @$items ) {
            $item->$filter();
        }
    }
}

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

    my $l = $self->live_objects;

    croak "Object not in storage"
        if grep { not defined } $l->objects_to_entries(@objects);

    $self->store_objects( shallow => 1, only_known => 1, objects => \@objects );
}

sub store_objects {
    my ( $self, %args ) = @_;

    my $objects = $args{objects};

    my ( $entries, @ids ) = $self->collapser->collapse(%args);

    if ( $args{root_set} ) {
        $_->root(1) for grep { defined } @{$entries}{@ids};
    }

    $self->backend->insert(values %$entries);

    # FIXME do something with prev for nested txns?
    $self->live_objects->update_entries(values %$entries);

    if ( @$objects == 1 ) {
        return $ids[0];
    } else {
        return @ids;
    }
}

sub delete {
    my ( $self, @ids_or_objects ) = @_;

    my $l = $self->live_objects;

    my ( @ids, @objects );

    push @{ ref($_) ? \@objects : \@ids }, $_ for @ids_or_objects;

    my @entries;

    push @entries, $l->objects_to_entries(@objects) if @objects;

    for ( @entries ) {
        croak "Object not in storage" unless defined;
    }

    @entries = map { $_->deletion_entry } @entries;

    # FIXME ideally if ID is pointing at a live object we should use its entry
    #push @entries, $l->ids_to_entries(@ids) if @ids;
    my @ids_or_entries = ( @entries, @ids );

    $self->backend->delete(@ids_or_entries);

    $l->update_entries(@entries);
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB - Promiscuous, schema-free, graph based persistence

=head1 SYNOPSIS

    use KiokuDB;

    my $d = KiokuDB->new(
        backend => KiokuDB::Backend::JSPON->new(
            dir => "/tmp/foo",
        ),
    );

    # takes a snapshot of $some_object
    my $uid = $d->store( $some_object );

    # ... some other place/time:
    my $some_object = $d->lookup($uid);

=head1 DESCRIPTION

Kioku is a Moose based frontend to various databases, somewhere in between
L<Tangram> and L<Pixie>. It builds on L<Class::MOP>'s solid foundation.

Its purpose is to provide persistence for "regular" objects with as little
effort as possible, without sacrificing control over how persistence is
actually done.

Kioku is also non-invasive: it does not use ties, AUTOLOAD, proxy objects,
C<sv_magic> or any other type of trickery to get its job done, to avoid
unwanted surprises.

Many features important for proper Perl space semantics are supported,
including shared data, circular structures, weak references, tied structures,
etc.

L<KiokuDB> is meant to solve two related persistence problems:

=over 4

=item Transparent persistence

Store arbitrary objects without changing their class definitions or worrying
about schema details.

=item Interoperability

Persisting arbitrary objects in a way that is compatible with existing
data/code (for example interoprating with another app using CouchDB with JSPON
semantics).

=back

=head1 TECHNICAL DETAILS

In order to use any persistence framework it is important to understand what it
does and how it does it.

Systems like L<Tangram> or L<DBIx::Class> generally require explicit meta data
and use a schema, which makes them fairly predictable.

When using transparent systems like L<KiokuDB> or L<Pixie> it is more important
to understand what's going on behind the scenes in order to avoid surprises and
limitations.

=head2 Collapsing

When an object is introduced to L<KiokuDB> it's collapsed into an
L<KiokDB::Entry|Entry>.

An entry is a simplified representation of the object, allowing the data to be
saved independently of other objects in formats as simple as JSON.

References to other objects are converted to symbolic references in the entry.

Collapsing is explained in detail in L<KiokuDB::Collapser>. The way an entry is
created varies with the object's class.

=head2 Linking

When objects are loaded, entries are retrieved from the backend using their
UIDs.

When a UID is already loaded (in the live object set of a L<KiokuDB> instance)
the live object is used. This way references to shared objects are shared in
memory regardless of the order the objects were stored or loaded.

This process is explained in detail in L<KiokuDB::Linker>.

=head1 ATTRIBUTES

L<KiokuDB> uses a number of delegates which do the actual work.

Of these only C<backend> is required, the rest have default definitions.

=over 4

=item backend

This attribute is required.

L<KiokuDB::Backend>.

The backend handles storage and retrieval of entries.

=item collapser

L<KiokuDB::Collapser>

The collapser prepares objects for storage.

=item linker

L<KiokuDB::Linker>

The linker links retrieved entries into functioning instances.

=item resolver

L<KiokuDB::Resolver>

The resolver swizzles memory addresses to UIDs and back.

=item live_objects

L<KiokuDB::LiveObjects>

The live object set keeps track of objects for the linker and the resolver.

=back

=head1 METHODS

=over 4

=item new %args

Creates a new directory object.

See L</ATTRIBUTES>

=item connect $dsn, %args

DWIM initialization.

=item lookup @ids

Fetches the objects for the specified IDs from the live object set or from
storage.

=item store @objects

Recursively collapses C<@objects> and inserts or updates the entries.

=item update @objects

Performs a shallow update of @objects.

It is an error to update an object not in the database.

=item insert @objects

Inserts objects to the database.

It is an error to insert objects that are already in the database.

=item delete @objects_or_ids

Deletes the specified objects from the store.

=back

=head1 GLOBALS

=over 4

=item C<$SERIAL_IDS>

If set at compile time, the default UUID generation role will use serial IDs,
instead of UUIDs.

This is useful for testing, since the same IDs will be issued each run, but is
utterly broken in the face of concurrency.

=back

=head1 VERSION CONTROL

L<http://code2.0beta.co.uk/moose/svn/>. Ask on #moose for commit bits.

=head1 AUTHOR

Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>

=head1 COPYRIGHT

    Copyright (c) 2008 Yuval Kogman, Infinity Interactive. All rights
    reserved This program is free software; you can redistribute
    it and/or modify it under the same terms as Perl itself.

=cut
