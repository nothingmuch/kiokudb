#!/usr/bin/perl

package MooseX::Storage::Directory::Collapser;
use Moose;

use Scope::Guard;
use Carp qw(croak);
use Scalar::Util qw(isweak);

use MooseX::Storage::Directory::Entry;
use MooseX::Storage::Directory::Reference;

use Data::Visitor 0.18;
use Data::Visitor::Callback;

use Set::Object qw(set);

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

has resolver => (
    isa => "MooseX::Storage::Directory::Resolver",
    is  => "rw",
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

    my $entries = $self->collapse( objects => \@objects );

    # compute the root set
    my @ids = $self->resolver->live_objects->objects_to_ids(@objects);
    my @root_set = delete @{ $entries }{@ids};

    # return the root set and all additional necessary entries
    return ( @root_set, values %$entries );
}

sub collapse_known_objects {
    my ( $self, @objects ) = @_;

    my $live_objects = $self->resolver->live_objects;

    my $entries = $self->collapse(
        objects    => \@objects,
        only_known => 1,
    );

    my @ids = $self->resolver->live_objects->objects_to_ids(@objects);
    my @root_set = map { $_ and delete $entries->{$_} } @ids;

    # return the root set and all additional necessary entries
    # may contain undefs
    return ( @root_set, values %$entries );
}

sub collapse {
    my ( $self, %args ) = @_;

    my $objects = delete $args{objects};

    if ( $args{only_known} ) {
        $args{live_objects} ||= $self->resolver->live_objects;
        $args{resolver}     ||= $args{live_objects};
    } else {
        $args{resolver}     ||= $self->resolver;
        $args{live_objects} ||= $args{resolver}->live_objects;
    }

    if ( $args{shallow} ) {
        $args{only} = set(@$objects);
    }

    my $g = Scope::Guard->new(sub {
        $self->clear_temp_structs;
    });

    my %entries;
    $self->_set_entries(\%entries);
    $self->_set_options(\%args);
    $self->_set_first_class({});
    $self->_set_simple_entries([]);

    # recurse through the object, accumilating entries
    $self->visit(@$objects);

    # compact UUID space by merging simple non shared structures into a single
    # deep entry
    $self->compact_entries() if $self->compact;

    return \%entries;
}

sub compact_entries {
    my $self = shift;

    my ( $entries, $fc, $simple, $options ) = ( $self->_entries, $self->_first_class, $self->_simple_entries, $self->_options );

    # unify non shared simple references
    # FIXME hashes and arrays should be registered in a Set::Object
    if ( my @flatten = grep { not exists $fc->{$_} } @$simple ) {
        my %flatten = map { $_ => undef } @flatten;

        my %purged;

        # FIXME for performance reasons make this more naïve, no need for full
        # Data::Visitor since the structures are very simple
        Data::Visitor::Callback->new(
            ignore_return_values => 1,
            'MooseX::Storage::Directory::Reference' => sub {
                my ( $v, $ref ) = @_;

                my $id = $ref->id;

                if ( exists $flatten{$id} ) {
                    # replace reference with data from entry, so that the
                    # simple data is inlined, and mark that entry for removal
                    $_ = $entries->{$id}->data;
                    $purged{$id} = undef;
                }
            }
        )->visit([ map { $_->data } values %$entries ]);

        # FIXME only remove if we allocated the ID
        # remove from the live objects and entries to store list
        delete @{$entries}{keys %purged};
        $options->{resolver}->remove(keys %purged);
    }
}

sub make_ref {
    my ( $self, $id, $value ) = @_;

    my $weak = isweak($_[2]);

    $self->_first_class->{$id} = undef if $weak;

    return MooseX::Storage::Directory::Reference->new(
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

        push @{ $self->_simple_entries }, $id;

        my $live_objects = $self->_options->{live_objects};
        my $prev = $live_objects->object_to_entry($ref);

        $self->_entries->{$id} = MooseX::Storage::Directory::Entry->new(
            live_objects => $live_objects,
            id           => $id,
            data         => $self->SUPER::visit_ref($_[1]),
            ( $prev ? ( prev => $prev ) : () ),
        );

        $self->make_ref( $id => $_[1] );
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

sub visit_object {
    my ( $self, $object ) = @_;

    # FIXME allow breaking out early if $object is in the live object cache
    # that is object_to_id is live_objects, not resolver
    # this is required for shallow updates, and of course much more efficient

    my $class = ref $object;

    if ( my $meta = Class::MOP::get_metaclass_by_name($class) ) {
        my $id = $self->_object_id($object) || return;

        if ( my $only = $self->_options->{only} ) {
            unless ( $only->contains($object) ) {
                return $self->make_ref( $id => $_[1] );
            }
        }

        # Data::Visitor stuff for circular refs
        $self->_register_mapping( $object, $object );

        my @attrs = $meta->compute_all_applicable_attributes;

        my $hash = {
            map {
                my $attr = $_;
                # FIXME readd MooseX::Storage::Engine type mappings here
                # need to refactor Engine, or go back to subclassing it
                my $value = $attr->get_value($object);
                my $collapsed = $self->visit($value);
                ( $attr->name => $collapsed );
            } grep {
                $_->has_value($object)
            } @attrs
        };

        my $live_objects = $self->_options->{live_objects};
        my $prev = $live_objects->object_to_entry($object);

        $self->_entries->{$id} = MooseX::Storage::Directory::Entry->new(
            live_objects => $live_objects,
            data         => $hash,
            id           => $id,
            class        => $class,
            ( $prev ? ( prev => $prev ) : () ),
        );

        # we pass $_[1], an alias, so that isweak works
        return $self->make_ref( $id => $_[1] );
    } else {
        croak "FIXME non moose objects";
    }
}

sub _object_id {
    my ( $self, $object ) = @_;
    $self->_options->{resolver}->object_to_id($object) or die { unknown => $object };
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::Storage::Directory::Collapser - Collapse object hierarchies to entry
data

=head1 SYNOPSIS

=head1 DESCRIPTION

This object walks object structures using L<Data::Visitor> and produces
simple standalone entries (no shared data, no circular references, no blessed
structures) with symbolic (UUID based) links.

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

