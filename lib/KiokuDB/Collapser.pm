#!/usr/bin/perl

package KiokuDB::Collapser;
use Moose;

no warnings 'recursion';

use Scope::Guard;
use Carp qw(croak);
use Scalar::Util qw(isweak refaddr reftype);

use KiokuDB::Entry;
use KiokuDB::Entry::Skip;
use KiokuDB::Reference;
use KiokuDB::Collapser::Buffer;
use KiokuDB::Error::UnknownObjects;

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

has backend => (
    does => "KiokuDB::Backend",
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

has '_buffer' => (
    isa => "KiokuDB::Collapser::Buffer",
    is  => "ro",
    clearer => "_clear_buffer",
    writer  => "_set_buffer",
);

sub collapse {
    my ( $self, %args ) = @_;

    my $objects = delete $args{objects};

    my $r;

    if ( $args{shallow} ) {
        $args{only} = set(@$objects);
    }

    my $buf = KiokuDB::Collapser::Buffer->new(
        live_objects => $self->live_objects,
        options      => \%args,
    );

    my $g = Scope::Guard->new(sub { $self->_clear_buffer });
    $self->_set_buffer($buf);

    # recurse through the object, accumilating entries
    $self->visit(@$objects);

    my @ids = $buf->merged_objects_to_ids(@$objects);

    $buf->first_class->insert(@ids);

    # compact UUID space by merging simple non shared structures into a single
    # deep entry
    $buf->compact_entries if $self->compact;

    return ( $buf, @ids );
}

sub may_compact {
    my ( $self, $ref_or_id ) = @_;

    my $id = ref($ref_or_id) ? $ref_or_id->id : $ref_or_id;

    not $self->_buffer->first_class->includes($id);
}

sub make_entry {
    my ( $self, %args ) = @_;

    if ( my $id = $args{id} ) {
        my $object = $args{object};

        my $prev = $self->live_objects->object_to_entry($object);

        my $entry = KiokuDB::Entry->new(
            ( $prev ? ( prev => $prev ) : () ),
            %args,
        );

        $self->_buffer->insert_entry( $id => $entry, $object );

        return $entry;
    } else {
        # intrinsic
        return KiokuDB::Entry->new(%args);
    }
}

sub make_skip_entry {
    my ( $self, %args ) = @_;

    my $object = $args{object};

    my $prev = $args{prev} || $self->live_objects->object_to_entry($object);

    my $id = $args{id};

    unless ( $id ) {
        croak "skip entries must have an ID" unless $prev;
        $id = $prev->id;
    }

    return undef;
}

sub make_ref {
    my ( $self, $id, $value ) = @_;

    my $weak = isweak($_[2]);

    $self->_buffer->first_class->insert($id) if $weak;

    return KiokuDB::Reference->new(
        id => $id,
        $weak ? ( is_weak => 1 ) : ()
    );
}

sub visit_seen {
    my ( $self, $seen, $prev ) = @_;

    my $b = $self->_buffer;

    if ( my $entry = $b->intrinsic_entry($seen) ) {
        return $entry->clone;
    } elsif ( my $id = $self->_buffer->object_to_id($seen) || $self->live_objects->object_to_id($seen) ) {
        $self->_buffer->first_class->insert($id) unless blessed($seen);

        # return a uuid ref
        return $self->make_ref( $id => $_[1] );
    } else {
        KiokuDB::Error::UnknownObjects->throw( objects => [ $seen ] );
    }
}

sub visit_ref_fallback {
    my ( $self, $ref ) = @_;

    my $o = $self->_buffer->options;

    if ( my $entry = $o->{only_new} && $self->live_objects->object_to_entry($ref) ) {
        return $self->make_ref( $entry->id => $_[1] );
    }

    if ( my $id = $self->_ref_id($ref) ) {
        if ( !$self->compact and my $only = $o->{only} ) {
            unless ( $only->contains($ref) ) {
                return $self->make_ref( $id => $_[1] );
            }
        }

        my $collapsed = $self->visit_ref_data($_[1]);

        if ( ref($collapsed) eq 'KiokuDB::Reference' and $collapsed->id eq $id ) {
            return $collapsed; # tied
        } else {
            push @{ $self->_buffer->simple_entries }, $id;

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
        KiokuDB::Error::UnknownObjects->throw( objects => [ $ref ] );
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
    } else {
        my $b = $self->_buffer;

        if ( $b->options->{only_known} ) {
            if ( $self->compact ) {
                # if we're compacting this is not an error, we just compact in place
                # and we generate an error if we encounter this data again in visit_seen
                return;
            } else {
                KiokuDB::Error::UnknownObjects->throw( objects => [ $ref ] );
            }
        } else {
            my $id = $self->generate_uuid;
            $b->insert( $id => $ref );
            return $id;
        }
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
        if ( !$self->compact and my $only = $self->_buffer->options->{only} ) {
            unless ( $only->contains($ref) ) {
                return $self->make_ref( $id => $_[1] );
            }
        }

        push @{ $self->_buffer->simple_entries }, $id;

        $self->make_entry(
            id     => $id,
            object => $ref,
            data   => $tie,
            tied   => substr(reftype($ref), 0, 1),
        );

        return $self->make_ref( $id => $_[2] );
    } else {
        return $self->make_entry(
            object => $ref,
            data   => $tie,
            tied   => substr(reftype($ref), 0, 1),
        );
    }
}

sub visit_object { shift->visit_with_typemap(@_) }
sub visit_ref { shift->visit_with_typemap(@_) }

sub visit_with_typemap {
    my ( $self, $ref ) = @_;

    my $collapse = $self->collapse_method(ref $ref);

    shift->$collapse(@_);
}

sub collapse_first_class {
    my ( $self, $collapse, $object, @entry_args ) = @_;

    # Data::Visitor stuff for circular refs
    $self->_register_mapping( $object, $object );

    my ( $l, $b ) = ( $self->live_objects, $self->_buffer );

    my $prev = $l->object_to_entry($object);

    my $o = $b->options;

    if ( $o->{only_new} && $prev ) {
        return $self->make_ref( $prev->id => $_[2] );
    }

    if ( my $only = $o->{only} ) {
        unless ( $only->contains($object) ) {
            if ( $prev ) {
                return $self->make_ref( $prev->id => $_[2] );
            } else {
                KiokuDB::Error::UnknownObjects->throw( objects => [ $object ] );
            }
        }
    }

    my $id = $l->object_to_id($object);

    unless ( $id ) {
        if ( $o->{only_known} ) {
            KiokuDB::Error::UnknownObjects->throw( objects => [ $object ] );
        } else {
            my $id_method = $self->id_method(ref $object);

            $id = $self->$id_method($object);

            if ( defined( my $conflict = $l->id_to_object($id) ) ) {
                return $self->id_conflict( $id, $_[2], $conflict );
            } else {
                $b->insert( $id => $object );
            }
        }
    }

    my @args = (
        object => $object,
        id     => $id,
        class  => ref($object),
        @entry_args,
    );

    $self->$collapse(@args);

    # we pass $_[1], an alias, so that isweak works
    return $self->make_ref( $id => $_[2] );
}

sub id_conflict {
    my ( $self, $id, $object, $other ) = @_;

    $self->make_skip_entry( id => $id, object => $object );

    $self->_buffer->insert( $id => $object );

    return $self->make_ref( $id => $_[2] );
}


sub collapse_intrinsic {
    my ( $self, $collapse, $object, @entry_args ) = @_;

    my $class = ref $object;

    my @args = (
        object => $object,
        class  => $class,
        @entry_args,
    );

    my $entry = $self->$collapse(@args);

    $self->_buffer->insert_intrinsic( $object => $entry );

    return $entry;
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
entries (filtered by C<< $object->isa($class) >>). The rationale is that a typemap
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

