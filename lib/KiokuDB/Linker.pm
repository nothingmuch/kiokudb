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

extends qw(Data::Visitor);

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
    handles => [qw(expand_method)],
    required => 1,
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
            push @objects, $self->expand_object($entry);
        }
    }

    return @objects;
}

sub expand_object {
    my ( $self, $entry ) = @_;

    #confess($entry) unless blessed($entry);

    if ( my $class = $entry->class ) {
        my $expand_method = $self->expand_method($class);
        return $self->$expand_method($entry);
    } else {
        return $self->expand_naive($entry);
    }
}

sub expand_naive {
    my ( $self, $entry ) = @_;

    $self->inflate_data( $entry, \(my $data) );

    $data;
}

sub inflate_data {
    my ( $self, $data, $into, $entry ) = @_;

    # Kinda ugly... inflates $data into the scalar ref in $into
    # but this allows us to handle weakening properly.
    # god I hate perl's reftypes, why couldn't they be a little more consistent

    unless ( ref $data ) {
        $$into = $data;
    } elsif ( ref $data eq 'KiokuDB::Reference' ) {
        my $id = $data->id;
        $$into = $self->get_or_load_object($id);
        weaken($$into) if $data->is_weak;
    } elsif ( ref $data eq 'KiokuDB::Entry' ) {
        my $obj;


        if ( my $class = $data->class ) {
            my $expand_method = $self->expand_method($class);
            $$into = $self->$expand_method($data);
        } else {
            $self->inflate_data($data->data, \$obj, ( $data->id ? $data : () ) ); # no id means intrinsic

            if ( my $tie = $data->tied ) {
                if ( $tie eq 'HASH' ) {
                    tie my %h, "Tie::ToObject" => $obj;
                    $obj = \%h;
                } elsif ( $tie eq 'ARRAY' ) {
                    tie my @a, "Tie::ToObject" => $obj;
                    $obj = \@a;
                } elsif ( $tie eq 'GLOB' ) {
                    my $glob = gensym();
                    tie *$glob, "Tie::ToObject" => $obj,
                    $obj = $glob;
                } elsif ( $tie eq 'SCALAR' ) {
                    my $scalar;
                    tie $scalar, "Tie::ToObject" => $obj;
                    $obj = \$scalar;
                } else {
                    die "Don't know how to tie $tie";
                }
            }

            $$into = $obj;
        }
    } elsif ( ref($data) eq 'HASH' ) {
        my %targ;
        $self->register_object( $entry => \%targ ) if $entry;
        foreach my $key ( keys %$data ) {
            $self->inflate_data( $data->{$key}, \$targ{$key});
        }
        $$into = \%targ;
    } elsif ( ref($data) eq 'ARRAY' ) {
        my @targ;
        $self->register_object( $entry => \@targ ) if $entry;
        for (@$data ) {
            push @targ, undef;
            $self->inflate_data($_, \$targ[-1]);
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

    my @missing = grep { not defined $objects{$_} } @ids;

    @objects{@missing} = $self->load_objects(@missing);

    return @objects{@ids};
}

sub load_objects {
    my ( $self, @ids ) = @_;

    my %entries;
    @entries{@ids} = $self->live_objects->ids_to_entries(@ids);

    if ( my @load = grep { !$entries{$_} } @ids ) {
        #confess if @load == 1;
        @entries{@load} = $self->backend->get(@load);

        if ( my @missing = grep { !$entries{$_} } @load ) {
            die { missing => \@missing };
        }

        $self->live_objects->insert_entries( @entries{@load} );
    }

    return $self->expand_objects( @entries{@ids} );
}

sub load_entries {
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

sub load_object {
    my ( $self, $id ) = @_;

    my ( $entry ) = $self->live_objects->ids_to_entries($id);

    unless ( $entry ) {
        $entry = ( $self->backend->get($id) )[0] || die { missing => [ $id ] };
        $self->live_objects->insert_entries($entry );
    }

    $self->expand_object($entry);
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Linker - Relinks live objects from storage entries

=head1 SYNOPSIS

=head1 DESCRIPTION

This object reconnects entry data using the MOP, constructing the connected
object graph in memory.

If a live object already exists for a UID then that object will be reused
instead of being loaded a second time.

=cut


