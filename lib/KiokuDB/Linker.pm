#!/usr/bin/perl

package KiokuDB::Linker;
use Moose;

# perf improvements:
# use a queue of required objects, queue up references, and bulk fetch
# bulk fetch arrays
# could support a Backend::Queueing which allows queuing of IDs for fetching,
# to help clump or start a request and only read it when it's actually needed


use Carp qw(croak);
use Scalar::Util qw(reftype weaken);
use Symbol qw(gensym);
use Tie::ToObject;

use namespace::clean -except => 'meta';

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    required => 1,
    handles => [qw(id_to_object ids_to_objects object_to_id objects_to_ids id_to_entry ids_to_entries)],
);

has backend => (
    does => "KiokuDB::Backend",
    is  => "ro",
    required => 1,
);

has typemap_resolver => (
    isa => "KiokuDB::TypeMap::Resolver",
    is  => "ro",
    handles => [qw(expand_method refresh_method)],
    required => 1,
);

has queue => (
    isa => "Bool",
    is  => "ro",
    default => 1,
);

has _queue => (
    isa => "ArrayRef",
    is  => "ro",
    default => sub { [] },
);

has _deferred => (
    isa => "ArrayRef",
    is  => "ro",
    default => sub { [] },
);

sub register_object {
    my ( $self, $entry, $object ) = @_;

    $self->live_objects->insert( $entry => $object ) if $entry->id;
}

sub expand_objects {
    my ( $self, @entries ) = @_;

    my $l = $self->live_objects;

    my @objects;

    foreach my $entry ( @entries ) {
        # if the object was referred to in some other entry in @entries, it may
        # have already been loaded.
        if ( defined ( my $obj = $l->id_to_object($entry->id) ) ) {
            push @objects, $obj;
        } else {
            $self->inflate_data( $entry, \($objects[@objects]) );
        }
    }

    $self->load_queue;

    return @objects;
}

sub expand_object {
    my ( $self, $entry ) = @_;

    $self->inflate_data( $entry, \(my $obj) );

    $self->load_queue;

    return $obj;
}

sub queue_ref {
    my ( $self, $ref, $into ) = @_;

    if ( 0 and $self->queue ) {

        #my $b = $self->backend;

        #if ( $b->can("prefetch") ) {
        #    $b->prefetch($ref->id);
        #}

        push @{ $self->_queue }, [ $ref, $into ];
    } else {
        if ( ref $ref ) {
            $$into = $self->get_or_load_object($ref->id);
            weaken($$into) if $ref->is_weak;
        } else {
            $$into = $self->get_or_load_object($ref);
        }
    }
}

sub queue_finalizer {
    my ( $self, @hooks ) = @_;

    if ( $self->queue ) {
        push @{ $self->_deferred }, @hooks;
    } else {
        foreach my $hook ( @hooks ) {
            $self->$hook();
        }
    }
}

sub load_queue {
    my $self = shift;

    return unless $self->queue;

    my $queue = $self->_queue;
    my $deferred = $self->_deferred;

    my @queue = @$queue;
    my @deferred = @$deferred;

    @$queue = ();
    @$deferred = ();

    if ( @queue ) {
        my @ids;

        foreach my $entry ( @queue ) {
            my $ref = $entry->[0];
            push @ids, ref($ref) ? $ref->id : $ref;
        }

        my @objects = $self->get_or_load_objects(@ids);

        foreach my $item ( @queue ) {
            my ( $data, $into ) = @$item;
            my $obj = shift @objects;

            $$into = $obj;

            weaken $$into if ref $data and $data->is_weak;
        }
    }

    if ( @deferred ) {
        foreach my $item ( @deferred ) {
            $self->$item;
        }
    }
}

sub inflate_data {
    my ( $self, $data, $into, $entry ) = @_;

    # Kinda ugly... inflates $data into the scalar ref in $into
    # but this allows us to handle weakening properly.
    # god I hate perl's reftypes, why couldn't they be a little more consistent

    unless ( ref $data ) {
        $$into = $data;
    } elsif ( ref $data eq 'KiokuDB::Reference' ) {
        $self->queue_ref( $data, $into );
    } elsif ( ref $data eq 'KiokuDB::Entry' ) {
        if ( my $class = $data->class ) {
            my $expand_method = $self->expand_method($class);
            $$into = $self->$expand_method($data);
        } else {
            my $obj;

            $self->inflate_data($data->data, \$obj, $data);

            $self->load_queue; # force vivification of $obj

            if ( my $tie = $data->tied ) {
                if ( $tie eq 'H' ) {
                    tie my %h, "Tie::ToObject" => $obj;
                    $obj = \%h;
                } elsif ( $tie eq 'A' ) {
                    tie my @a, "Tie::ToObject" => $obj;
                    $obj = \@a;
                } elsif ( $tie eq 'G' ) {
                    my $glob = gensym();
                    tie *$glob, "Tie::ToObject" => $obj,
                    $obj = $glob;
                } elsif ( $tie eq 'S' ) {
                    my $scalar;
                    tie $scalar, "Tie::ToObject" => $obj;
                    $obj = \$scalar;
                } else {
                    die "Don't know how to tie $tie";
                }
            }

            $$into = $obj;
        }

        $data->object($$into);
    } elsif ( ref($data) eq 'HASH' ) {
        my %targ;
        $self->register_object( $entry => \%targ ) if $entry;
        foreach my $key ( keys %$data ) {
            $self->inflate_data( $data->{$key}, \$targ{$key} );
        }
        $$into = \%targ;
    } elsif ( ref($data) eq 'ARRAY' ) {
        my @targ;
        $self->register_object( $entry => \@targ ) if $entry;
        for (@$data ) {
            push @targ, undef;
            $self->inflate_data( $_, \$targ[-1] );
        }
        $$into = \@targ;
    } elsif ( ref($data) eq 'SCALAR' ) {
        my $targ = $$data;
        $self->register_object( $entry => \$targ ) if $entry;
        $$into = \$targ;
    } elsif ( ref($data) eq 'REF' ) {
        my $targ;
        $self->register_object( $entry => \$targ ) if $entry;
        $self->inflate_data( $$data, \$targ );
        $$into = \$targ;
    } else {
        if ( blessed($data) ) {
            # this branch is for passthrough intrinsic values
            $self->register_object( $entry => $data ) if $entry;
            $$into = $data;
        } else {
            die "unsupported reftype: " . ref $data;
        }
    }
}

sub get_or_load_objects {
    my ( $self, @ids ) = @_;

    return $self->get_or_load_object($ids[0]) if @ids == 1;

    my %objects;
    @objects{@ids} = $self->live_objects->ids_to_objects(@ids);

    my @missing = grep { not defined $objects{$_} } keys %objects; # @ids may contain duplicates

    @objects{@missing} = $self->load_objects(@missing);

    return @objects{@ids};
}

sub load_objects {
    my ( $self, @ids ) = @_;

    return $self->expand_objects( $self->get_or_load_entries(@ids) );
}

sub get_or_load_entries {
    my ( $self, @ids ) = @_;

    my %entries;
    @entries{@ids} = $self->ids_to_entries(@ids);

    if ( my @load = grep { !$entries{$_} } @ids ) {
        @entries{@load} = $self->load_entries(@load);
    }

    return @entries{@ids};
}

sub load_entries {
    my ( $self, @ids ) = @_;

    my @entries = $self->backend->get(@ids);

    if ( @entries != @ids or grep { !$_ } @entries ) {
        my %entries;
        @entries{@ids} = @entries;
        my @missing = grep { !$entries{$_} } @ids;
        die { missing => \@missing };
    }

    $self->live_objects->insert_entries( @entries );

    return @entries;
}

sub register_and_expand_entries {
    my ( $self, @entries ) = @_;

    $self->live_objects->insert_entries(@entries),
    $self->expand_objects(@entries);
}

sub get_or_load_object {
    my ( $self, $id ) = @_;

    if ( defined( my $obj = $self->live_objects->id_to_object($id) ) ) {
        return $obj;
    } else {
        return $self->load_object($id);
    }
}

sub refresh_objects {
    my ( $self, @objects ) = @_;

    $self->refresh_object($_) for @objects;
}

sub refresh_object {
    my ( $self, $object ) = @_;

    my $id = $self->object_to_id($object);

    my $entry = $self->load_entry($id);

    my $refresh = $self->refresh_method( $entry->class );

    $self->$refresh($object, $entry);
    $self->load_queue;

    return $object;
}

sub get_or_load_entry {
    my ( $self, $id ) = @_;

    $self->id_to_entry($id) || $self->load_entry($id);
}

sub load_entry {
    my ( $self, $id ) = @_;

    my $entry = ( $self->backend->get($id) )[0] || die { missing => [ $id ] };

    $self->live_objects->insert_entries($entry);

    return $entry;
}

sub load_object {
    my ( $self, $id ) = @_;

    $self->expand_object( $self->get_or_load_entry($id) );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Linker - Relinks live objects from storage entries

=head1 SYNOPSIS

    # mostly internal

=head1 DESCRIPTION

The linker reconnects entry data, recreating the connected object graph in
memory.

The linkage process starts with a an ID (or several IDs) to be loaded passed to
the C<get_or_load_objects> method.

This ID will first be searched for in the live object set
(L<KiokuDB::LiveObjects>). If the object is already live, then it will be
returned as is.

If the object is not live, then the corresponding entry is fetched from the
backend, and expanded into an actual instance.

Expansion consults the L<KiokuDB::TypeMap> using L<KiokuDB::TypeMap::Resolver>,
to find the correct typemap entry (see
L<KiokuDB::Collapser/"COLLAPSING STRATEGIES"> and L<KiokuDB::TypeMap>), and
that is used for the actual expansion.

Most of the grunt work is delegated by the entries back to the linker using the
C<inflate_data> method, which handles circular structures, retrying of tied
structures, etc.

Inflated objects are registered with L<KiokuDB::LiveObjects>, and get inserted
into the current live object scope (L<KiokuDB::LiveObjects::Scope>). The
scope's job is to maintain a reference count of at least 1 for any loaded
object, until it is destroyed itself. This ensures that weak references are not
destroyed prematurely, but allows their use in order to avoid memory leaks.

=cut

