#!/usr/bin/perl

package MooseX::Storage::Directory::Collapser;
use Moose;

use Carp qw(croak);
use Scalar::Util qw(isweak refaddr);

use MooseX::Storage::Directory::Entry;
use MooseX::Storage::Directory::Reference;

use Data::Visitor 0.18;
use Data::Visitor::Callback;

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
    default  => sub { +{} },
);

# a list of the IDs of all simple entries
has _simple_entries => (
    isa => 'ArrayRef',
    is  => "ro",
    init_arg => undef,
    default  => sub { [] },
);

# keeps track of the simple references which are first class (either weak or
# shared, and must have an entry)
has _first_class => (
    isa => 'HashRef',
    is  => "ro",
    init_arg => undef,
    default  => sub { +{} },
);

has _options => (
    isa => 'HashRef',
    is  => "ro",
    init_arg => undef,
    default  => sub { +{} },
);

sub collapse_objects {
    my ( $self, @objects ) = @_;

    my $entries = $self->collapse( objects => \@objects );

    # compute the root set
    my @ids = $self->resolver->live_objects->objects_to_ids(@objects);
    my @root_set = delete @{ $entries }{@ids};

    # return the root set and all additional necessary entries
    return ( @root_set, values %$entries );
}

sub shallow_collapse_objects {
    my ( $self, @objects ) = @_;

    my $live_objects = $self->resolver->live_objects;

    my $entries = $self->collapse(
        objects      => \@objects,
        resolver     => $live_objects,
        live_objects => $live_objects,
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

    my $resolver     = $args{resolver}     ||= $self->resolver;
    my $live_objects = $args{live_objects} ||= $resolver->live_objects;

    # set up localized env that we don't want to pass around all the time
    my ( $entries, $fc, $simple, $options ) = ( $self->_entries, $self->_first_class, $self->_simple_entries, $self->_options );
    local %$entries = ();
    local %$fc      = ();
    local @$simple  = ();
    local %$options = %args;

    # recurse through the object, accumilating entries
    $self->visit(@$objects);

    # compact UUID space by merging simple non shared structures into a single
    # deep entry
    $self->compact_entries() if $self->compact;

    return {%$entries}; # gotta make a copy, it's localized
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

    my $id = $self->_seen_id($seen) || return;

    # register ID as first class
    $self->_first_class->{$id} = undef;

    # return a uuid ref
    return $self->make_ref( $id => $_[1] );
}

sub _seen_id {
    my ( $self, $seen ) = @_;

    if ( my $id = $self->_options->{live_objects}->object_to_id($seen) ) {
        return $id;
    } elsif ( $self->compact ) {
        return refaddr($seen);
    }

    return;
}

sub visit_ref {
    my ( $self, $ref ) = @_;

    # FIXME for shallow visiting to work we need to subvert this case,
    # allocating a private temporary ID if compact is true.

    my $id = $self->_ref_id($ref) || return;

    push @{ $self->_simple_entries }, $id;
    
    $self->_entries->{$id} = MooseX::Storage::Directory::Entry->new(
        id   => $id,
        data => $self->SUPER::visit_ref($_[1]),
    );

    $self->make_ref( $id => $_[1] );
}

sub _ref_id {
    my ( $self, $ref ) = @_;

    if ( my $id = $self->_options->{resolver}->object_to_id($ref) ) {
        return $id;
    } elsif ( $self->compact ) {
        return refaddr($self);
    }

    return;
}

sub visit_object {
    my ( $self, $object ) = @_;

    # FIXME allow breaking out early if $object is in the live object cache
    # that is object_to_id is live_objects, not resolver
    # this is required for shallow updates, and of course much more efficient

    if ( $object->can("meta") ) {
        my $id = $self->_object_id($object) || return;

        # Data::Visitor stuff for circular refs
        $self->_register_mapping( $object, $object );

        my $meta = $object->meta;

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

        $self->_entries->{$id} = MooseX::Storage::Directory::Entry->new(
            data  => $hash,
            id    => $id,
            class => $meta,
        );

        return $self->make_ref( $id => $_[1] );
    } else {
        croak "FIXME non moose objects";
    }
}

sub _object_id {
    my ( $self, $object ) = @_;
    $self->_options->{resolver}->object_to_id($object);
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

