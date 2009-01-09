#!/usr/bin/perl

package KiokuDB::Collapser;
use Moose;

no warnings 'recursion';

use Scope::Guard;
use Carp qw(croak);
use Scalar::Util qw(isweak refaddr reftype);

use KiokuDB::Entry;
use KiokuDB::Reference;

use Data::Visitor 0.18;

use Set::Object qw(set);

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

with qw(KiokuDB::Role::UUIDs);

has '+tied_as_objects' => ( default => 1 );

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    required => 1,
);

has typemap_resolver => (
    isa => "KiokuDB::TypeMap::Resolver",
    is  => "ro",
    handles => [qw(collapse_method id_method)],
    required => 1,
);

has compact => (
    isa => "Bool",
    is  => "rw",
    default => 1,
);

has '+weaken' => (
    default => 0,
);

has _entries => (
    isa => 'HashRef',
    is  => "ro",
    init_arg => undef,
    clearer => "_clear_entries",
    writer  => "_set_entries",
);

# a list of the IDs of all simple entries
has _simple_entries => (
    isa => 'ArrayRef',
    is  => "ro",
    init_arg => undef,
    clearer => "_clear_simple_entries",
    writer  => "_set_simple_entries",
);

# keeps track of the simple references which are first class (either weak or
# shared, and must have an entry)
has _first_class => (
    isa => 'HashRef',
    is  => "ro",
    init_arg => undef,
    clearer => "_clear_first_class",
    writer  => "_set_first_class",
);

has _options => (
    isa => 'HashRef',
    is  => "ro",
    init_arg => undef,
    clearer => "_clear_options",
    writer  => "_set_options",
);

sub clear_temp_structs {
    my $self = shift;
    $self->_clear_entries;
    $self->_clear_simple_entries;
    $self->_clear_first_class;
    $self->_clear_options;
}

sub collapse_objects {
    my ( $self, @objects ) = @_;

    my ( $entries, @ids ) = $self->collapse( objects => \@objects );

    # compute the root set
    my @root_set = delete @{ $entries }{@ids};

    # return the root set and all additional necessary entries
    return ( @root_set, values %$entries );
}

sub collapse_known_objects {
    my ( $self, @objects ) = @_;

    my ( $entries, @ids ) = $self->collapse(
        objects    => \@objects,
        only_known => 1,
    );

    my @root_set = map { $_ and delete $entries->{$_} } @ids;

    # return the root set and all additional necessary entries
    # may contain undefs
    return ( @root_set, values %$entries );
}

sub collapse {
    my ( $self, %args ) = @_;

    my $objects = delete $args{objects};

    my $r;

    if ( $args{shallow} ) {
        $args{only} = set(@$objects);
    }

    my $g = Scope::Guard->new(sub {
        $self->clear_temp_structs;
    });

    my ( %entries, %fc );

    $self->_set_entries(\%entries);
    $self->_set_options(\%args);
    $self->_set_first_class(\%fc);
    $self->_set_simple_entries([]);

    # recurse through the object, accumilating entries
    $self->visit(@$objects);

    my @ids = $self->live_objects->objects_to_ids(@$objects);
    @fc{@ids} = ();

    # compact UUID space by merging simple non shared structures into a single
    # deep entry
    $self->compact_entries() if $self->compact;

    return ( \%entries, @ids );
}

sub may_compact {
    my ( $self, $ref_or_id ) = @_;

    my $id = ref($ref_or_id) ? $ref_or_id->id : $ref_or_id;

    not exists $self->_first_class->{$id};
}

sub compact_entries {
    my $self = shift;

    my ( $entries, $fc, $simple, $options ) = ( $self->_entries, $self->_first_class, $self->_simple_entries, $self->_options );

    # unify non shared simple references
    if ( my @flatten = grep { not exists $fc->{$_} } @$simple ) {
        my $flatten = {};
        @{$flatten}{@flatten} = delete @{$entries}{@flatten};

        $self->live_objects->remove(@flatten);

        $self->compact_entry($_, $flatten) for values %$entries;
    }
}

sub compact_entry {
    my ( $self, $entry, $flatten ) = @_;

    my $data = $entry->data;

    if ( $self->compact_data($data, $flatten) ) {
        $entry->data($data);
    }
}

sub compact_data {
    my ( $self, $data, $flatten ) = @_;

    if ( ref $data eq 'KiokuDB::Reference' ) {
        my $id = $data->id;

        if ( my $entry = $flatten->{$id} ) {
            # replace reference with data from entry, so that the
            # simple data is inlined, and mark that entry for removal
            $self->compact_entry($entry, $flatten);

            if ( $entry->tied or $entry->class ) {
                $entry->clear_id;
                $_[1] = $entry;
            } else {
                $_[1] = $entry->data;
            }
            return 1;
        }
    } elsif ( ref($data) eq 'ARRAY' ) {
        ref && $self->compact_data($_, $flatten) for @$data;
    } elsif ( ref($data) eq 'HASH' ) {
        ref && $self->compact_data($_, $flatten) for values %$data;
    } elsif ( ref($data) eq 'KiokuDB::Entry' ) {
        $self->compact_entry($data, $flatten);
    } else {
        # passthrough
    }

    return;
}

sub make_entry {
    my ( $self, %args ) = @_;

    my $object = $args{object};

    my $live_objects = $self->live_objects;

    if ( my $id = $args{id} ) {
        my $prev = $live_objects->object_to_entry($object);

        return $self->_entries->{$id} = KiokuDB::Entry->new(
            ( $prev ? ( prev => $prev ) : () ),
            %args,
        );
    } else {
        # intrinsic
        return KiokuDB::Entry->new(%args);
    }
}

sub make_ref {
    my ( $self, $id, $value ) = @_;

    my $weak = isweak($_[2]);

    $self->_first_class->{$id} = undef if $weak;

    return KiokuDB::Reference->new(
        id => $id,
        $weak ? ( is_weak => 1 ) : ()
    );
}

sub visit_seen {
    my ( $self, $seen, $prev ) = @_;

    my $id = $self->_seen_id($seen);


    # register ID as first class
    $self->_first_class->{$id} = undef;

    # return a uuid ref
    return $self->make_ref( $id => $_[1] );
}

sub _seen_id {
    my ( $self, $seen ) = @_;

    if ( my $id = $self->live_objects->object_to_id($seen) ) {
        return $id;
    }

    die { unknown => $seen };
}

sub visit_ref {
    my ( $self, $ref ) = @_;

    if ( my $entry = $self->_options->{only_new} && $self->live_objects->object_to_entry($ref) ) {
        return $self->make_ref( $entry->id => $_[1] );
    }

    if ( my $id = $self->_ref_id($ref) ) {
        if ( !$self->compact and my $only = $self->_options->{only} ) {
            unless ( $only->contains($ref) ) {
                return $self->make_ref( $id => $_[1] );
            }
        }

        my $collapsed = $self->visit_ref_data($_[1]);

        if ( ref($collapsed) eq 'KiokuDB::Reference' and $collapsed->id eq $id ) {
            return $collapsed; # tied
        } else {
            push @{ $self->_simple_entries }, $id;

            $self->make_entry(
                id     => $id,
                object => $ref,
                data   => $collapsed,
            );

            return $self->make_ref( $id => $_[1] );
        }
    } elsif ( $self->compact and not isweak($_[1]) ) {
        # for now we assume this data just won't be shared, instead of
        # compacting it later.
        return $self->SUPER::visit_ref($_[1]);
    } else {
        die { unknown => $ref };
    }
}

sub visit_ref_data {
    my ( $self, $ref ) = @_;
    $self->SUPER::visit_ref($_[1]);
}

sub _ref_id {
    my ( $self, $ref ) = @_;

    my $l = $self->live_objects;

    if ( my $id = $l->object_to_id($ref) ) {
        return $id;
    } elsif ( $self->_options->{only_known} ) {
        if ( $self->compact ) {
            # if we're compacting this is not an error, we just compact in place
            # and we generate an error if we encounter this data again in _seen_id
            return;
        } else {
            die { unknown => $ref };
        }
    } else {
        my $id = $self->generate_uuid;
        $l->insert( $id => $ref ); # FIXME see _object_id... this shouldn't be "comitted" to the live objects yet
        return $id;
    }
}

# avoid retying, we want to get back Reference or Entry objects
sub visit_tied_hash   { shift->visit_tied(@_) }
sub visit_tied_array  { shift->visit_tied(@_) }
sub visit_tied_scalar { shift->visit_tied(@_) }
sub visit_tied_glob   { shift->visit_tied(@_) }

sub visit_tied {
    my ( $self, $tied, $ref ) = @_;

    my $tie = $self->visit($tied);

    if ( my $id = $self->_ref_id($ref) ) {
        if ( !$self->compact and my $only = $self->_options->{only} ) {
            unless ( $only->contains($ref) ) {
                return $self->make_ref( $id => $_[1] );
            }
        }

        push @{ $self->_simple_entries }, $id;

        $self->make_entry(
            id     => $id,
            object => $ref,
            data   => $tie,
            tied   => reftype($ref),
        );

        return $self->make_ref( $id => $_[2] );
    } else {
        return $self->make_entry(
            object => $ref,
            data   => $tie,
            tied   => reftype($ref),
        );
    }
}

sub visit_object {
    my ( $self, $object ) = @_;

    my $collapse = $self->collapse_method(ref $object);

    $self->$collapse($_[1]);
}

sub collapse_first_class {
    my ( $self, $collapse, $object, @entry_args ) = @_;

    my $o = $self->_options;

    my $l = $self->live_objects;

    if ( my $entry = $o->{only_new} && $l->object_to_entry($object) ) {
        return $self->make_ref( $entry->id => $_[1] );
    }

    # Data::Visitor stuff for circular refs
    $self->_register_mapping( $object, $object );

    my $id = $self->_object_id($object, @entry_args) || return;

    if ( my $only = $self->_options->{only} ) {
        unless ( $only->contains($object) ) {
            return $self->make_ref( $id => $_[1] );
        }
    }

    my $class = ref $object;

    my @args = (
        object => $object,
        id     => $id,
        class  => $class,
        @entry_args,
    );

    my $data = $self->$collapse(@args);

    $self->make_entry(
        @args,
        data => $data,
    );

    # we pass $_[1], an alias, so that isweak works
    return $self->make_ref( $id => $_[1] );
}

sub collapse_intrinsic {
    my ( $self, $collapse, $object, @entry_args ) = @_;

    my $class = ref $object;

    delete $self->{_seen}{ refaddr($object) }; # FIXME Data::Visitor ->_remove_mapping?

    my @args = (
        object => $object,
        class  => $class,
        @entry_args,
    );

    return $self->make_entry(
        @args,
        data  => $self->$collapse(@args),
    );
}

sub _object_id {
    my ( $self, $object, %args ) = @_;

    my $l = $self->live_objects;

    if ( my $id = $l->object_to_id($object) ) {
        return $id;
    } else {
        my $o = $self->_options;
        if ( $o && $o->{only_known} ) {
            die { unknown => $object };
        }

        my $method = $self->id_method(ref $object);
        my $id = $self->$method($object) || die "ID method failed to return an ID";

        $l->insert( $id => $object ); # FIXME only do this when about to insert an entry? maybe some sort of accumilation zone?

        return $id;
    }
}

# we don't reblass in collapse_naive
sub retain_magic {
    my ( $self, $proto, $clone ) = @_;
    return $clone;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Collapser - Collapse object hierarchies to entry
data

=head1 SYNOPSIS

    # mostly internal

=head1 DESCRIPTION

The collapser simplifies real objects into L<KiokuDB::Entry> objects to pass to
the backend.

Non object data is collapsed by walking it with L<Data::Visitor> (which
L<KiokuDB::Collapser> inherits from).

Object collapsing is detailed in L</"COLLAPSING STRATEGIES">.

The object's data will be copied into the L<KiokuDB::Entry> with references to
other data structures translated into L<KiokuDB::Reference> objects.

Reference addresses are mapped to unique identifiers, which are generated as
necessary.

=head2 Compacting

If C<compact> is disabled then every reference is symbolic, and every data
structure has an entry.

If compacting is enabled (the default) the minimum number of entry objects
required for consistency is created.

Every blessed, shared or tied data structure requires an entry object, as does
every target of a weak reference. "Simple" structures, such as plain
hashes/arrays will be left inline as data intrinsic to the object it was found in.

Compacting is usually desirable, but sometimes isn't (for instance with an RDF
like store).

=head1 COLLAPSING STRATEGIES

Collapsing strategies are chosen based on the type of the object being
collapsed, using L<KiokuDB::TypeMap::Resolver>.

The resolver consults the typemap (L<KiokuDB::TypeMap>), and caches the results
as keyed by C<ref $object>.

The typemap contains normal entries (keyed by C<ref $object eq $class>) or isa
entries (filtered by C<$object->isa($class)>). The rationale is that a typemap
entry for a superclass might not support all subclasses as well.

Any strategy may be collapsed as a first class object, or intrinsicly, inside
its parent (in which case it isn't assigned a UUID). This is determined based
on the C<intrinsic> attribute to the entry. For instance, if L<Path::Class>
related objects should be collapsed as if they are values, the following
typemap entry can be used:

    isa_entries => {
        'Path::Class::Entity' => KiokuDB::TypeMap::Entry::Callback->new(
            intrinsic => 1,
            collapse  => "stringify",
            expand    => "new",
        ),
    },

If no typemap entry exists, L<KiokuDB::TypeMap::Entry::MOP> is used by default.
See L<KiokuDB::TypeMap::Resolver> for more details.

These are the strategies in brief:

=head2 MOP

When the object has a L<Class::MOP> registered metaclass (any L<Moose> object,
but not only), the MOP is used to walk the object's attributes and construct
the simplified version without breaking encapsulation.

See L<KiokuDB::TypeMap::Entry::MOP>.

=head2 Naive

This collapsing strategy simply walks the object's data using L<Data::Visitor>.

This allows collapsing of L<Class::Accessor> based objects, for instance, but
should be used with care.

See L<KiokuDB::TypeMap::Entry::Naive>

=head2 Callback

This collapsing strategy allows callbacks to be used to map the types.

It is more limited than the other strategies, but very convenient for simple
values.

See L<KiokuDB::TypeMap::Entry::Callback> for more details.

=head2 Passthrough

This delegates collapsing to the backend serialization. This is convenient for
when a backend uses e.g. L<Storable> to serialize entries, and the object in
question already has a C<STORABLE_freeze> and C<STORABLE_thaw> method.

=cut

