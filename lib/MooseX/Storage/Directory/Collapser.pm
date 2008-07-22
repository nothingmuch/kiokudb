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

has _accum_uids => (
    isa => 'HashRef',
    is  => "ro",
    init_arg => undef,
    default  => sub { +{} },
);

has _shared => (
    isa => 'HashRef',
    is  => "ro",
    init_arg => undef,
    default  => sub { +{} },
);

has _simple_entries => (
    isa => 'ArrayRef',
    is  => "ro",
    init_arg => undef,
    default  => sub { [] },
);

sub collapse_objects {
    my ( $self, @objects ) = @_;

    my ( $entries, $shared, $simple ) = ( $self->_accum_uids, $self->_shared, $self->_simple_entries );
    local %$entries = ();
    local %$shared  = ();
    local @$simple  = ();

    my @ids = $self->objects_to_ids(@objects);

    # Collection is ignored by the entry creation code, but we want them in one
    # visit() call so that the shared refs are truly shared ;-)
    $self->visit(bless( \@objects, 'MooseX::Storage::Directory::Collapser::Collection'));

    # unify non shared simple references
    if ( my @non_shared = grep { not exists $shared->{$_} } @$simple ) {
        my %non_shared = map { $_ => 1 } @non_shared;

        my $l = $self->resolver->live_objects;

        my %purged;

        # FIXME for performance reasons make this more naïve, no need for full
        # Data::Visitor since the structures are very simple
        Data::Visitor::Callback->new(
            ignore_return_values => 1,
            'MooseX::Storage::Directory::Reference' => sub {
                my ( $v, $ref ) = @_;

                my $id = $ref->id;
                if ( exists $non_shared{$id} and not $ref->is_weak ) {
                    my $entry = $entries->{$id};

                    unless ( $entry->has_class ) {
                        # replace with data from entry
                        $_ = $entry->data;
                        $purged{$id} = $entry;
                    }
                }
            }
        )->visit([ map { $_->data } values %$entries ]);

        foreach my $id ( keys %purged ) {
            delete $entries->{$id};
            $l->remove($id);
        }
    }

    my @root_set = delete @{ $entries }{@ids};

    $_->root(1) for @root_set;

    return ( @root_set, values %$entries );
}

sub make_ref {
    my ( $self, $id, $value ) = @_;
    
    my $weak = isweak($_[2]);

    $self->_shared->{$id} = undef if $weak;

    return MooseX::Storage::Directory::Reference->new(
        id => $id,
        $weak ? ( is_weak => 1 ) : ()
    );
}

sub visit_seen {
    my ( $self, $seen, $prev ) = @_;

    my $id = $self->object_to_id($seen);

    $self->_shared->{$id} = undef;

    $self->make_ref( $id => $_[1] );
}

sub visit_ref {
    my ( $self, $ref ) = @_;

    my $id = $self->object_to_id($ref);

    push @{ $self->_simple_entries }, $id;
    
    $self->_accum_uids->{$id} = MooseX::Storage::Directory::Entry->new(
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

    if ( ref $object eq 'MooseX::Storage::Directory::Collapser::Collection' ) {
        $self->visit_object($_) for @$object;
        return undef;
    }

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

        $self->_accum_uids->{$id} = MooseX::Storage::Directory::Entry->new(
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

