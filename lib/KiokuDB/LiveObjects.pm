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
use KiokuDB::LiveObjects::TXNScope;

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

has txn_scope => (
    isa => "KiokuDB::LiveObjects::TXNScope",
    is  => "ro",
    writer   => "_set_txn_scope",
    clearer  => "_clear_txn_scope",
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

sub new_txn {
    my $self = shift;

    my $parent = $self->txn_scope;

    my $child = KiokuDB::LiveObjects::TXNScope->new(
        ( $parent ? ( parent => $parent ) : () ),
        live_objects => $self,
    );

    $self->_set_txn_scope($child);

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

    if ( my $s = $self->txn_scope ) {
        $s->update_entries(@entries);
    }

    @ret;
}

sub rollback_entries {
    my ( $self, @entries ) = @_;

    my ( $o, $i, $ei ) = ( $self->_objects, $self->_ids, $self->_entry_ids );

    foreach my $entry ( reverse @entries ) {
        my $id = $entry->id;

        if ( my $prev = $entry->prev ) {
            $ei->{$id} = $prev;

            my $obj = $i->{$id};

            $o->{$obj}{entry} = $prev;
        } else {
            delete $ei->{$id};
            delete $i->{$id};
        }
    }
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

    confess "non reference entries: ", join ", ", map { $_ ? $_ : "undef" } @entries if grep { !ref } @entries;

    my $i = $self->_ids;

    @entries = grep { not exists $i->{$_->id} } @entries;

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

    $live_objects->insert( $entry => $object );

    $live_objects->insert( $id => $object );

    my $id = $live_objects->object_to_id( $object );

    my $obj = $live_objects->id_to_object( $id );

    my $scope = $live_objects->new_scope;

=head1 DESCRIPTION

This object keeps track of the set of live objects, their associated IDs, and
the storage entries.

=head1 METHODS

=over 4

=item insert

Takes pairs, id or entry as the key, and object as the value, registering the
objects.

=item insert_entries

Takes entries and registers them without an object.

This is used when prefetching entries, before their objects are actually
inflated.

=item objects_to_ids

=item object_to_id

Given objects, returns their IDs, or undef for objects which not registered.

=item objects_to_entries

=item object_to_entry

Given objects, find the corresponding entries.

=item update_entries

Given entries, replaces the live entries of the corresponding objects with the
newly updated ones.

The objects must already be in the live object set.

This method is called on a successful transaction commit.

=item new_scope

Creates a new L<KiokuDB::LiveObjects::Scope>, with the current scope as its
parent.

=item current_scope

The current L<KiokuDB::LiveObjects::Scope> instance.

This is the scope into which newly registered objects are pushed.

=item new_txn

Creates a new L<KiokuDB::LiveObjects::TXNScope>, with the current txn scope as
its parent.

=item txn_scope

The current L<KiokuDB::LiveObjects::TXNScope>.

=item clear

Forces a clear of the live object set.

This removes all objects and entries, and can be useful in the case of leaks
(to prevent false positives on lookups).

Note that this does not actually break the circular structures, so the leak is
unresolved, but the objects are no longer considered live by the L<KiokuDB> instance.

=item live_entries

=item live_objects

=item live_ids

Enumerates the live entries, objects or ids.

=item rollback_entries

Called by L<KiokuDB::LiveObjects::TXNScope/rollback>.

=item remove

Removes entries from the live object set.

=back

=cut
