#!/usr/bin/perl

package KiokuDB::Collapser;
use Moose;

# perf improvements:
# cache of expansders keyed by ref($data)
# could use this to do short/long term immutable style collapsers

use Scope::Guard;
use Carp qw(croak);
use Scalar::Util qw(isweak refaddr reftype);

use KiokuDB::Entry;
use KiokuDB::Reference;

use Data::Visitor 0.18;

use Set::Object qw(set);

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

has '+tied_as_objects' => ( default => 1 );

has resolver => (
    isa => "KiokuDB::Resolver",
    is  => "ro",
    required => 1,
);

has typemap_resolver => (
    isa => "KiokuDB::TypeMap::Resolver",
    is  => "ro",
    handles => [qw(collapse_method)],
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

    if ( $args{only_known} ) {
        $args{live_objects}  ||= $self->resolver->live_objects;
        $r = $args{resolver} ||= $args{live_objects};
    } else {
        $r = $args{resolver} ||= $self->resolver;
        $args{live_objects}  ||= $args{resolver}->live_objects;
    }

    my @ids = $r->objects_to_ids(@$objects);
    foreach my $id ( @ids ) {
        unless ( $id ) {
            foreach my $object ( @$objects ) {
                next if shift @ids;
                die { unknown => $object };
            }
        }
    }

    if ( $args{shallow} ) {
        $args{only} = set(@$objects);
    }

    my $g = Scope::Guard->new(sub {
        $self->clear_temp_structs;
    });

    my ( %entries, %fc );
    @fc{@ids} = ();

    $self->_set_entries(\%entries);
    $self->_set_options(\%args);
    $self->_set_first_class(\%fc);
    $self->_set_simple_entries([]);

    # recurse through the object, accumilating entries
    $self->visit(@$objects);

    # compact UUID space by merging simple non shared structures into a single
    # deep entry
    $self->compact_entries() if $self->compact;

    return ( \%entries, @ids );
}

sub compact_entries {
    my $self = shift;

    my ( $entries, $fc, $simple, $options ) = ( $self->_entries, $self->_first_class, $self->_simple_entries, $self->_options );

    # unify non shared simple references
    if ( my @flatten = grep { not exists $fc->{$_} } @$simple ) {
        my $flatten = {};
        @{$flatten}{@flatten} = delete @{$entries}{@flatten};


        $options->{resolver}->remove(@flatten);

        $self->compact_entry($_, $flatten) for values %$entries;
    }
}

sub compact_entry {
    my ( $self, $entry, $flatten ) = @_;

    my $data = $entry->data;

    if ( $self->compact_data($data, $flatten) ) {
        warn "Replacing";
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
        confess "unsupported reftype: " . ref $data;
    }

    return;
}

sub make_entry {
    my ( $self, %args ) = @_;

    my $object = $args{object};

    my $live_objects = $self->_options->{live_objects};

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

    if ( my $id = $self->_options->{live_objects}->object_to_id($seen) ) {
        return $id;
    }

    die { unknown => $seen };
}

sub visit_ref {
    my ( $self, $ref ) = @_;

    if ( my $id = $self->_ref_id($ref) ) {
        if ( !$self->compact and my $only = $self->_options->{only} ) {
            unless ( $only->contains($ref) ) {
                return $self->make_ref( $id => $_[1] );
            }
        }

        my $collapsed = $self->SUPER::visit_ref($_[1]);

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

sub _ref_id {
    my ( $self, $ref ) = @_;

    if ( my $id = $self->_options->{resolver}->object_to_id($ref) ) {
        return $id;
    } elsif ( $self->compact ) {
        # if we're compacting this is not an error, we just compact in place
        # and we generate an error if we encounter this data again in _seen_id
        return;
    }

    die { unknown => $ref };
}

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

    $self->$collapse($object);
}

sub collapse_first_class {
    my ( $self, $collapse, $object ) = @_;

    # Data::Visitor stuff for circular refs
    $self->_register_mapping( $object, $object );

    my $id = $self->_object_id($object) || return;

    if ( my $only = $self->_options->{only} ) {
        unless ( $only->contains($object) ) {
            return $self->make_ref( $id => $_[1] );
        }
    }

    my $class = ref $object;

    my @args = (
        object => $object,
        id     => $id,
        class  => $class
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
    my ( $self, $collapse, $object ) = @_;

    my $class = ref $object;

    delete $self->{_seen}{ refaddr($object) }; # FIXME Data::Visitor ->_remove_mapping?

    my @args = (
        object => $object,
        class  => $class
    );

    return $self->make_entry(
        data  => $self->$collapse(@args),
        class => $class,
    );
}

sub _object_id {
    my ( $self, $object ) = @_;
    $self->_options->{resolver}->object_to_id($object) or die { unknown => $object };
}

sub collapse_naive {
    my ( $self, %args ) = @_;

    my $object = $args{object};

    return $self->SUPER::visit_ref($object);
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

=head1 DESCRIPTION

The collapser simplifies real objects into L<KiokuDB::Entry> objects to pass to
the backend.

Non object data is collapsed by walking it with L<Data::Visitor>.

Object collapsing is detailed in L</"COLLAPSING STRATEGIES">.

The object's data will be copied into the L<KiokuDB::Entry> with references to
other data structures translated into L<KiokuDB::Reference> objects.

Reference addresses are resolved to UIDs by L<KiokuDB::Resolver>.

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
collapsed.

=head2 MOP

When the object has a L<Class::MOP> registered metaclass (any L<Moose> object,
but not only), the MOP is used to walk the object's attributes and construct
the simplified version without breaking encapsulation.

Annotations on the meta attributes, like L<MooseX::Storarge> meta traits
can precisely control which attributes get serialized and how.

=head2 Type Map

A type map is consulted for objects without a meta class.

The default type map contains entries for a number of fairly standard classes
(e.g. L<Path::Class>, L<DateTime>, etc).

=head2 L<Pixie::Complicity> / L<Tangram::Complicity>

The C<px_thaw> and C<px_freeze> methods can be defined on your object to
convert them to "pure" perl data structures.

=head2 Naive

If desired, naive collaping will simply walk the object's reference using
L<Data::Visitor>.

This is disabled by default and should be enabled on a case by case basis, but
can be done for all unknown objects too.

=head1 TODO

=over 4

=item *

Tied data

=item *

Custom hooks

=item *

Non moose objects

(Adapt L<Storable> hooks, L<Pixie::Complicity>, etc etc)

=back

=cut

