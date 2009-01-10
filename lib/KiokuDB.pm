#!/usr/bin/perl

package KiokuDB;
use Moose;

our $VERSION = "0.19";

use constant SERIAL_IDS => not not our $SERIAL_IDS;

use KiokuDB::Backend;
use KiokuDB::Collapser;
use KiokuDB::Linker;
use KiokuDB::LiveObjects;
use KiokuDB::TypeMap;
use KiokuDB::TypeMap::Shadow;
use KiokuDB::TypeMap::Resolver;
use KiokuDB::Stream::Objects;

use Hash::Util::FieldHash::Compat qw(idhash);
use Carp qw(croak);

use namespace::clean -except => [qw(meta SERIAL_IDS)];

sub connect {
    my ( $class, $dsn, @args ) = @_;

    if ( -d $dsn ) {
        return $class->configure($dsn, @args);
    } else {
        require KiokuDB::Util;
        return $class->new( backend => KiokuDB::Util::dsn_to_backend($dsn, @args), @args );
    }
}

sub configure {
    my ( $class, $base, @args ) = @_;

    require Path::Class;
    $base = Path::Class::dir($base) unless blessed $base;

    require KiokuDB::Util;
    my $config = KiokuDB::Util::load_config($base);

    my $backend = KiokuDB::Util::config_to_backend( $config, base => $base, @args );

    # FIXME gin extractor, typemap, etc
    $class->new( %$config, @args, backend => $backend );
}

has typemap => (
    does => "KiokuDB::Role::TypeMap",
    is   => "ro",
    lazy_build => 1,
);

sub _build_typemap {
    KiokuDB::TypeMap->new;
}

has merged_typemap => (
    does => "KiokuDB::Role::TypeMap",
    is   => "ro",
    lazy_build => 1,
);

sub _find_default_typemap {
    my $self = shift;

    my $b = $self->backend;

    if ( $b->can("default_typemap") ) {
        return $b->default_typemap;
    } elsif( $b->can("serializer") and $b->serializer->can("default_typemap") ) {
        return $b->serializer->default_typemap;
    }

    return;
}

sub _build_merged_typemap {
    my $self = shift;

    if ( my $default_typemap = $self->_find_default_typemap ) {
        return KiokuDB::TypeMap::Shadow->new(
            typemaps => [
                $self->typemap,
                $default_typemap,
            ],
        );
    } else {
        return $self->typemap;
    }
}

has typemap_resolver => (
    isa => "KiokuDB::TypeMap::Resolver",
    is  => "ro",
    lazy_build => 1,
);

sub _build_typemap_resolver {
    my $self = shift;

    KiokuDB::TypeMap::Resolver->new(
        typemap => $self->merged_typemap,
    );
}

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    lazy => 1,
    builder => "_build_live_objects", # lazy_build => 1 sets clearer
    handles => {
        clear_live_objects => "clear",
        new_scope          => "new_scope",
        object_to_id       => "object_to_id",
        objects_to_ids     => "objects_to_ids"
    },
);

sub _build_live_objects { KiokuDB::LiveObjects->new }

has collapser => (
    isa => "KiokuDB::Collapser",
    is  => "ro",
    lazy_build => 1,
);

sub _build_collapser {
    my $self = shift;

    KiokuDB::Collapser->new(
        live_objects => $self->live_objects,
        typemap_resolver => $self->typemap_resolver,
    );
}

has backend => (
    does => "KiokuDB::Backend",
    is   => "ro",
    required => 1,
    coerce   => 1,
    handles  => [qw(exists)],
);

has linker_queue => (
    isa => "Bool",
    is  => "ro",
    default => 1,
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
        queue => $self->linker_queue,
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

sub _load_entry_stream {
    my ( $self, $stream ) = @_;

    KiokuDB::Stream::Objects->new(
        directory => $self,
        entry_stream => $stream,
    );
}

sub simple_search {
    my ( $self, @args ) = @_;

    my $b = $self->backend;

    my $entries = $b->simple_search( @args, live_objects => $self->live_objects );

    my $objects = $self->_load_entry_stream($entries);

    return $b->simple_search_filter($objects, @args);
}

sub backend_search {
    my ( $self, @args ) = @_;

    my $b = $self->backend;

    my $entries = $b->search( @args, live_objects => $self->live_objects );

    my $objects = $self->_load_entry_stream($entries);

    return $b->search_filter($objects, @args);
}

sub root_set {
    my ( $self ) = @_;

    $self->_load_entry_stream( $self->backend->root_entries );
}

sub all_objects {
    my ( $self ) = @_;

    $self->_load_entry_stream( $self->backend->all_entries );
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

sub _parse_args {
    my ( $self, @args ) = @_;

    my ( %ids, @ret );

    while ( @args ) {
        my $next = shift @args;

        unless ( ref $next ) {
            my $obj = shift @args;

            $ids{$next} = $obj;

            push @ret, $obj;
        } else {
            push @ret, $next;
        }
    }

    return ( \%ids, @ret );
}

sub _register {
    my ( $self, @args ) = @_;

    my ( $ids, @objs ) = $self->_parse_args(@args);

    if ( scalar keys %$ids ) {
        $self->live_objects->insert(%$ids);
    }

    return @objs;
}

sub store {
    my ( $self, @args ) = @_;

    my @objects = $self->_register(@args);

    $self->store_objects( root_set => 1, objects => \@objects );
}

sub insert {
    my ( $self, @args ) = @_;

    my @objects = $self->_register(@args);

    idhash my %entries;

    @entries{@objects} = $self->live_objects->objects_to_entries(@objects);

    # FIXME make optional?
    if ( my @in_storage = grep { $entries{$_} } @objects ) {
        croak "Objects already in database: @in_storage";
    }

    $self->store_objects( root_set => 1, only_new => 1, objects => \@objects );

    # return IDs only for unknown objects
    if ( defined wantarray ) {
        return $self->live_objects->objects_to_ids(@objects);
    }
}

sub update {
    my ( $self, @args ) = @_;

    my @objects = $self->_register(@args);

    my $l = $self->live_objects;

    croak "Object not in storage"
        if grep { not defined } $l->objects_to_entries(@objects);

    $self->store_objects( shallow => 1, only_known => 1, objects => \@objects );
}

sub deep_update {
    my ( $self, @args ) = @_;

    my @objects = $self->_register(@args);

    my $l = $self->live_objects;

    croak "Object not in storage"
        if grep { not defined } $l->objects_to_entries(@objects);

    $self->store_objects( only_known => 1, objects => \@objects );
}

sub _imply_root {
    my ( $self, @entries ) = @_;

    foreach my $entry ( @entries ) {
        next if $entry->has_root; # set by typemap
        $entry->root(1);
    }
}

sub set_root {
    my ( $self, @objects ) = @_;
    $_->root(1) for $self->live_objects->objects_to_entries(@objects);
}

sub unset_root {
    my ( $self, @objects ) = @_;
    $_->root(0) for $self->live_objects->objects_to_entries(@objects);
}

sub store_objects {
    my ( $self, %args ) = @_;

    my $objects = $args{objects};

    my ( $entries, @ids ) = $self->collapser->collapse(%args);

    if ( $args{root_set} ) {
        $self->_imply_root(@{$entries}{@ids});
    }

    $self->backend->insert(values %$entries);

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

sub txn_do {
    my ( $self, $code, %args ) = @_;

    my $backend = $self->backend;

    if ( $backend->can("txn_do") ) {
        my $scope = $self->live_objects->new_txn;

        my $rollback = $args{rollback};
        $args{rollback} = sub { $scope->rollback; $rollback && $rollback->() };

        $backend->txn_do( $code, %args );
    } else {
        return $code->();
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB - Object Graph storage engine

=head1 SYNOPSIS

    use KiokuDB;

    # use a DSN
    my $d = KiokuDB->connect( $dsn, %args );

    # or manually instantiate a backend
    my $d = KiokuDB->new(
        backend => KiokuDB::Backend::Files->new(
            dir        => "/tmp/foo",
            serializer => "yaml",
        ),
    );


    # takes a snapshot of $some_object
    my $uuid = $d->store($some_object);

    # or with a custom ID:
    $d->store( $id => $some_object ); # $id can be any string


    # retrieve by ID
    my $some_object = $d->lookup($uuid);



    # some backends (like DBI) support simple searchs
    $d->search({ name => "foo" });


    # others use GIN queries (DBI supports both)
    $d->search($gin_query);

=head1 ALPHA WARNING

L<KiokuDB> is still in its infancy. No fundamental changes are expected, but
nevertheless backwards compatibility is not yet guaranteed.

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
about schema details, and without needing to conform to the limitations of
a relational model.

=item Interoperability

Persisting arbitrary objects in a way that is compatible with existing
data/code (for example interoprating with another app using CouchDB with JSPON
semantics).

=back

=head1 FUNDAMENTAL CONCEPTS

In order to use any persistence framework it is important to understand what it
does and how it does it.

Systems like L<Tangram> or L<DBIx::Class> generally require explicit meta data
and use a schema, which makes them fairly predictable.

When using transparent systems like L<KiokuDB> or L<Pixie> it is more important
to understand what's going on behind the scenes in order to avoid surprises and
limitations.

=head2 Collapsing

When an object is stored using L<KiokuDB> it's collapsed into an
L<KiokDB::Entry|Entry>.

An entry is a simplified representation of the object, allowing the data to be
saved in formats as simple as JSON.

References to other objects are converted to symbolic references in the entry,
so objects can be saved independently of each other.

The entries are given to the L<KiokuDB::Backend|Backend> for actual storage.

Collapsing is explained in detail in L<KiokuDB::Collapser>. The way an entry is
created varies with the object's class.

=head2 Linking

When objects are loaded, entries are retrieved from the backend using their
UIDs.

When a UID is already loaded (in the live object set of a L<KiokuDB> instance,
see L<KiokuDB::LiveObjects>) the live object is used. This way references to
shared objects are shared in memory regardless of the order the objects were
stored or loaded.

This process is explained in detail in L<KiokuDB::Linker>.

=head1 ROOT SET MEMBERSHIP

Any object that is passed to C<store> or C<insert> directly is implicitly
considered a member of the root set.

This flag implies that the object is an identified resource and should not be
garbage collected with any of the proposed garbage collection schemes.

The root flag may be modified explicitly:

    $kiokudb->set_root(@objects); # or unset_root

    $kiokudb->update(@objects);

Lastly, root set membership may also be specified explicitly by the typemap.

A root set member must be explicitly using C<delete> or removed from the root
set before it will be purged with any garbage collection scheme.

=head1 ATTRIBUTES

L<KiokuDB> uses a number of delegates which do the actual work.

Of these only C<backend> is required, the rest have default definitions.

Additional attributes that are not commonly used are listed in L</"INTERNAL
ATTRIBUTES">.

=over 4

=item backend

This attribute is required.

This must be an object that does L<KiokuDB::Backend>.

The backend handles storage and retrieval of entries.

=item typemap

This is an instance L<KiokuDB::TypeMap>.

The typemap contains entries which control how L<KiokuDB::Collapser> and
L<KiokuDB::Linker> handle different types of objects.

=back

=head1 METHODS

=over 4

=item connect $dsn, %args

DWIM wrapper for C<new>.

C<$dsn> represents some sort of backend (much like L<DBI> dsns map to DBDs).

An example DSN is:

    my $dir = KiokuDB->connect("bdb:dir=path/to/data/");

The backend moniker name is extracted by splitting on the colon. The rest of
the string is passed tp C<new_from_dsn>, which is documented in more detail in
L<KiokuDB::Backend>.

Typically DSN arguments are separated by C<;>, with C<=> separating keys and
values. Arguments with no value are assumed to denote boolean truth (e.g.
C<jspon:dir=foo;pretty> means c<dir => "foo", pretty => 1>).

Extra arguments are passed both to the backend constructor, and the C<KiokuDB>
constructor.

Note that if you need a typemap you still need to pass it in:

    KiokuDB->connect( $dsn, typemap => $typemap );

=item configure $config_file, %args

TODO

=item new %args

Creates a new directory object.

See L</ATTRIBUTES>

=item new_scope

Creates a new object scope. Handled by C<live_objects>.

The object scope artificially bumps up the reference count of objects to ensure
that they live at least as long as the scope does.

This ensures that weak references aren't deleted prematurely, and the object
graph doesn't get corrupted without needing to create circular structures and
cleaning up leaks manually.

=item lookup @ids

Fetches the objects for the specified IDs from the live object set or from
storage.

=item store @objects

Recursively collapses C<@objects> and inserts or updates the entries.

This performs a full update of every reachable object from C<@objects>,
snapshotting everything.

=item update @objects

Performs a shallow update of @objects (referants are not updated).

It is an error to update an object not in the database.

=item deep_update @objects

Update @objects and all of the objects they reference.

=item insert @objects

Inserts objects to the database.

It is an error to insert objects that are already in the database, all elements
of C<@objects> must be new, but their referants don't have to be.

C<@objects> will be collapsed recursively, but the collapsing stops at known
objects, which will not be updated.

=item delete @objects_or_ids

Deletes the specified objects from the store.

Note that this can cause lookup errors if the object you are deleting is
referred to by another object, because that link will be broken.

=item set_root @objects

=item unset_root @objects

Modify the C<root> flag on the associated entries.

C<update> must be called for the change to take effect.

=item txn_do $code, %args

Executes $code within the scope of a transaction.

This requires that the backend supports transactions
(L<KiokuDB::Backend::Role::TXN>).

Transactions may be nested.

=item search \%proto

=item search @args

Searching requires a backend that supports querying.

The C<\%proto> form is currently unspecified but in the future should provide a
simple but consistent way of looking objects by attributes.

The second form is backend specific querying, for instance
L<Search::GIN::Query> objects passed to L<KiokuDB::Backend::BDB::GIN> or
the generic GIN backend wrapper L<KiokuDB::GIN>.

=item root_set

Returns a L<Data::Stream::Bulk> of all the root objects in the database.

=item all_objects

Returns a L<Data::Stream::Bulk> of all the objects in the database.

=item grep $filter

Returns a L<Data::Stream::Bulk> of the objects in C<root_set> filtered by
C<$filter>.

=item scan $callback

Iterates the root set calling C<$callback> for each object.

=back

=head1 GLOBALS

=over 4

=item C<$SERIAL_IDS>

If set at compile time, the default UUID generation role will use serial IDs,
instead of UUIDs.

This is useful for testing, since the same IDs will be issued each run, but is
utterly broken in the face of concurrency.

=back

=head1 INTERNAL ATTRIBUTES

These attributes are documented for completeness and should typically not be
needed.

=over 4

=item collapser

L<KiokuDB::Collapser>

The collapser prepares objects for storage, by creating L<KiokDB::Entry>
objects to pass to the backend.

=item linker

L<KiokuDB::Linker>

The linker links entries into functioning instances, loading necessary
dependencies from the backend.

=item live_objects

L<KiokuDB::LiveObjects>

The live object set keeps track of objects and entries for the linker and the
resolver.

It also creates scope objects that help ensure objects don't garbage collect
too early (L<KiokuDB::LiveObjects/new_scope>, L<KiokuDB::LiveObjects::Scope>),
and transaction scope objects used by C<txn_do>
(L<KiokuDB::LiveObjects::TXNScope>).

=item typemap_resolver

An instance of L<KiokuDB::TypeMap::Resolver>. Handles actual lookup and
compilation of typemap entries, using the user typemap.

=back

=head1 SEE ALSO

=head2 Prior Art on the CPAN

=over 4

=item L<Pixie>

=item L<DBM::Deep>

=item L<OOPS>

=item L<Tangram>

=item L<DBIx::Class>

Polymorphic retrieval is possible with L<DBIx::Class::DynamicSubclass>

=item L<Fey::ORM>

=item L<MooseX::Storage>

=back

=head1 VERSION CONTROL

KiokuDB is maintained using Git. Information about the repository is available
on L<http://www.iinteractive.com/kiokudb/>

=head1 AUTHOR

Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>

=head1 COPYRIGHT

    Copyright (c) 2008, 2009 Yuval Kogman, Infinity Interactive. All
    rights reserved This program is free software; you can redistribute
    it and/or modify it under the same terms as Perl itself.

=cut
