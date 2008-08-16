#!/usr/bin/perl

package MooseX::Storage::Directory::Collapser;
use Moose;

use Carp qw(croak);
use Scalar::Util qw(isweak);

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
    handles => [qw(objects_to_ids object_to_id)],
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

sub collapse_objects {
    my ( $self, @objects ) = @_;

    my ( $entries, $fc, $simple ) = ( $self->_entries, $self->_first_class, $self->_simple_entries );
    local %$entries = ();
    local %$fc      = ();
    local @$simple  = ();

    my @ids = $self->objects_to_ids(@objects);

    $self->visit(@objects);

    # unify non shared simple references
    # FIXME hashes and arrays should be Set::Object
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

        # remove from the live objects and entries to store list
        delete @{$entries}{keys %purged};
        $self->resolver->remove(keys %purged);
    }


    my @root_set = delete @{ $entries }{@ids};

    $_->root(1) for @root_set;

    return ( @root_set, values %$entries );
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

    my $id = $self->object_to_id($seen);

    $self->_first_class->{$id} = undef;

    $self->make_ref( $id => $_[1] );
}

sub visit_ref {
    my ( $self, $ref ) = @_;

    my $id = $self->object_to_id($ref);

    push @{ $self->_simple_entries }, $id;
    
    $self->_entries->{$id} = MooseX::Storage::Directory::Entry->new(
        id   => $id,
        data => $self->SUPER::visit_ref($_[1]),
    );

    $self->make_ref( $id => $_[1] );
}

sub visit_object {
    my ( $self, $object ) = @_;

    # FIXME allow breaking out early if $object is in the live object cache
    # that is object_to_id is live_objects, not resolver
    # this is required for shallow updates, and of course much more efficient

    if ( $object->can("meta") ) {
        my $id = $self->object_to_id($object);

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

