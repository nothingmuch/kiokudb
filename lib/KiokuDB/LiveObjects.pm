#!/usr/bin/perl

package KiokuDB::LiveObjects;
use Moose;

use MooseX::AttributeHelpers;

use Scalar::Util qw(weaken);
use Scope::Guard;
use Hash::Util::FieldHash::Compat qw(fieldhash);
use Carp qw(croak);
use Devel::PartialDump qw(croak);
use Set::Object;

use KiokuDB::LiveObjects::Scope;

use namespace::clean -except => 'meta';

has _objects => (
    isa => "HashRef",
    is  => "ro",
    init_arg => undef,
    default => sub { fieldhash my %hash },
);

has _ids => (
    metaclass => 'Collection::Hash',
    isa => "HashRef",
    is  => "ro",
    init_arg => undef,
    default => sub { return {} },
    provides => {
        get    => "ids_to_objects",
        keys   => "live_ids",
        values => "live_objects",
    },
);

has _entry_objects => (
    isa => "HashRef",
    is  => "ro",
    init_arg => undef,
    default => sub { fieldhash my %hash },
);

has _entry_ids => (
    metaclass => 'Collection::Hash',
    isa => "HashRef",
    is  => "ro",
    init_arg => undef,
    default  => sub { return {} },
    provides => {
        get    => "ids_to_entries",
        keys   => "loaded_ids",
        values => "live_entries",
    },
);

has current_scope => (
    isa => "KiokuDB::LiveObjects::Scope",
    is  => "ro",
    writer   => "_set_current_scope",
    clearer  => "_clear_current_scope",
    weak_ref => 1,
);

sub new_scope {
    my $self = shift;

    my $parent = $self->current_scope;

    my $child = KiokuDB::LiveObjects::Scope->new(
        ( $parent ? ( parent => $parent ) : () ),
        live_objects => $self,
    );

    $self->_set_current_scope($child);

    return $child;
}

sub id_to_object {
    my ( $self, $id ) = @_;
    scalar $self->ids_to_objects($id);
}

sub objects_to_ids {
    my ( $self, @objects ) = @_;

    return $self->object_to_id($objects[0])
        if @objects == 1;

    my $o = $self->_objects;

    return map {
        my $ent = $o->{$_};
        $ent && $ent->{id};
    } @objects;
}

sub object_to_id {
    my ( $self, $obj ) = @_;

    if ( my $ent = $self->_objects->{$obj} ){
        return $ent->{id};
    }

    return undef;
}

sub objects_to_entries {
    my ( $self, @objects ) = @_;

    return $self->object_to_entry($objects[0])
        if @objects == 1;

    my $o = $self->_objects;

    return map {
        my $ent = $o->{$_};
        $ent && $ent->{entry};
    } @objects;
}

sub object_to_entry {
    my ( $self, $obj ) = @_;

    if ( my $ent = $self->_objects->{$obj} ){
        return $ent->{entry};
    }

    return undef;
}

sub update_entries {
    my ( $self, @entries ) = @_;

    my @ret;

    my ( $o, $i, $eo, $ei ) = ( $self->_objects, $self->_ids, $self->_entry_objects, $self->_entry_ids );

    foreach my $entry ( @entries ) {
        my $id = $entry->id;

        my $obj = $i->{$id};

        croak "The object doesn't exist"
            unless defined $obj;

        weaken($ei->{$id} = $entry);
        $eo->{$entry} ||= Scope::Guard->new(sub { delete $ei->{$id} });

        my $ent = $o->{$obj};

        push @ret, $ent->{entry} if defined wantarray;
        $ent->{entry} = $entry;
    }

    @ret;
}

sub remove {
    my ( $self, @stuff ) = @_;

    my ( $o, $i, $eo, $ei ) = ( $self->_objects, $self->_ids, $self->_entry_objects, $self->_entry_ids );

    foreach my $thing ( @stuff ) {
        if ( ref $thing ) {
            delete $o->{$thing}; # guard invokes
            delete $eo->{$thing}; # in case it's a ref, same deal
        } else {
            if ( ref( my $object = delete $i->{$thing} ) ) {
                if ( my $ent = delete $o->{$object} ) {
                    $ent->{guard}->dismiss;
                }
            }

            if ( my $entry = $ei->{$thing} ) {
                delete($eo->{$entry})->dismiss;
            }
        }
    }
}

sub insert {
    my ( $self, @pairs ) = @_;

    croak "The arguments must be an list of pairs of IDs/Entries to objects"
        unless @pairs % 2 == 0;

    my ( $o, $i, $eo, $ei ) = ( $self->_objects, $self->_ids, $self->_entry_objects, $self->_entry_ids );

    my $s = $self->current_scope or croak "no open live object scope";

    while ( @pairs ) {
        my ( $id, $object ) = splice @pairs, 0, 2;
        my $entry;

        if ( ref $id ) {
            $entry = $id;
            $id = $entry->id;
        }

        confess("blah") unless $id;

        croak($object, " is not a reference") unless ref($object);
        croak($object, " is an entry") if blessed($object) && $object->isa("KiokuDB::Entry");
        croak($object, " is already registered as $o->{$object}{id}") if exists $o->{$object};

        if ( exists $i->{$id} ) {
            croak "An object with the id '$id' is already registered";
        } else {
            weaken($i->{$id} = $object);

            $s->push($object);

            if ( $entry and !$ei->{$id} ) {
                $ei->{$id} = $entry;
                $eo->{$entry} = Scope::Guard->new(sub { delete $ei->{$id} });
            }

            # note, $entry = $e->{$id} is *not* desired, it isn't necessarily
            # up to date

            $o->{$object} = {
                id => $id,
                entry => $entry,
                guard => Scope::Guard->new(sub { delete $i->{$id} }),
            };
        }
    }
}

sub insert_entries {
    my ( $self, @entries ) = @_;

    confess if grep { !ref } @entries;

    my @ids = map { $_->id } @entries;

    my $ei = $self->_entry_ids;
    @{ $self->_entry_objects }{@entries} = map { my $id = $_; Scope::Guard->new(sub { delete $ei->{$id} }) } @ids;
    weaken($_) for @{$ei}{@ids} = @entries;
    return;
}

sub clear {
    my $self = shift;

    foreach my $ent ( values %{ $self->_objects } ) {
        if ( my $guard = $ent->{guard} ) { # sometimes gone in global destruction
            $guard->dismiss;
        }
    }

    foreach my $guard ( grep { $_ } values %{ $self->_entry_objects } ) {
        $guard->dismiss;
    }

    # avoid the now needless weaken magic, should be faster
    %{ $self->_objects } = ();
    %{ $self->_ids }     = ();

    %{ $self->_entry_ids } = ();
    %{ $self->_entry_objects } = ();
}

sub DEMOLISH {
    my $self = shift;
    $self->clear;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::LiveObjects - Live object set tracking

=head1 SYNOPSIS

=head1 DESCRIPTION

This object keeps track of the set of live objects and their associated UIDs.

=cut
