#!/usr/bin/perl

package KiokuDB::LiveObjects;
use Moose;

use Scalar::Util qw(weaken refaddr);
use KiokuDB::LiveObjects::Guard;
use Hash::Util::FieldHash::Compat qw(fieldhash);
use Carp qw(croak);
BEGIN { local $@; eval 'use Devel::PartialDump qw(croak)' };
use Set::Object;

use KiokuDB::LiveObjects::Scope;
use KiokuDB::LiveObjects::TXNScope;

use namespace::clean -except => 'meta';

has clear_leaks => (
    isa => "Bool",
    is  => "rw",
);

has leak_tracker => (
    isa => "CodeRef|Object",
    is  => "rw",
    clearer => "clear_leak_tracker",
);

has _objects => (
    isa => "HashRef",
    is  => "ro",
    init_arg => undef,
    default => sub { fieldhash my %hash },
);

has _ids => (
    #metaclass => 'Collection::Hash',
    isa => "HashRef",
    is  => "ro",
    init_arg => undef,
    default => sub { return {} },
    #provides => {
    #    get    => "ids_to_objects",
    #    keys   => "live_ids",
    #    values => "live_objects",
    #},
);

sub id_to_object {
    my ( $self, $id ) = @_;
    $self->_ids->{$id};
}

sub ids_to_objects {
    my ( $self, @ids ) = @_;
    @{ $self->_ids }{@ids};
}

sub live_ids {
    keys %{ shift->_ids };
}

sub live_objects {
    values %{ shift->_ids };
}

has _entry_objects => (
    isa => "HashRef",
    is  => "ro",
    init_arg => undef,
    default => sub { fieldhash my %hash },
);

has _entry_ids => (
    #metaclass => 'Collection::Hash',
    isa => "HashRef",
    is  => "ro",
    init_arg => undef,
    default  => sub { return {} },
    #provides => {
    #    get    => "ids_to_entries",
    #    keys   => "loaded_ids",
    #    values => "live_entries",
    #},
);

sub id_to_entry {
    my ( $self, $id ) = @_;
    $self->_entry_ids->{$id};
}

sub ids_to_entries {
    my ( $self, @ids ) = @_;
    @{ $self->_entry_ids }{@ids}
}

sub loaded_ids {
    keys %{ shift->_entry_ids };
}

sub live_entries {
    values %{ shift->_entry_ids };
}

has current_scope => (
    isa => "KiokuDB::LiveObjects::Scope",
    is  => "ro",
    writer   => "_set_current_scope",
    clearer  => "_clear_current_scope",
    weak_ref => 1,
);

has _known_scopes => (
    isa => "Set::Object",
    is  => "ro",
    default => sub { Set::Object::Weak->new },
);

sub detach_scope {
    my ( $self, $scope ) = @_;

    my $current_scope = $self->current_scope;
    if ( defined($current_scope) and refaddr($current_scope) == refaddr($scope) ) {
        if ( my $parent = $scope->parent ) {
            $self->_set_current_scope($parent);
        } else {
            $self->_clear_current_scope;
        }
    }
}

sub remove_scope {
    my ( $self, $scope ) = @_;

    $self->detach_scope($scope);

    $scope->clear;

    my $known = $self->_known_scopes;

    $known->remove($scope);

    if ( $known->size == 0 ) {
        if ( my @objects = $self->live_objects ) {
            if ( $self->clear_leaks ) {
                $self->clear;
            }

            if ( my $tracker = $self->leak_tracker ) {
                if ( ref($tracker) eq 'CODE' ) {
                    $tracker->(@objects);
                } else {
                    $tracker->leaked_objects(@objects);
                }
            }
        }
    }
}

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

    $self->_known_scopes->insert($child);

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

        push @ret, $ei->{$id} if defined wantarray;

        weaken($ei->{$id} = $entry);
        $eo->{$entry} ||= KiokuDB::LiveObjects::Guard->new( $ei, $id );

        if ( ref(my $obj = $i->{$id}) ) {
            my $ent = $o->{$obj};
            $ent->{entry} = $entry;
        } elsif ( ref( my $object = $entry->object ) ) {
            $self->insert( $entry => $object );
        }
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
            delete $eo->{$thing};
            if ( my $id = (delete $o->{$thing} || {})->{id} ) { # guard invokes
                delete $i->{$id};
                delete $ei->{$id};
            }
        } else {
            if ( ref( my $object = delete $i->{$thing} ) ) {
                delete $o->{$object};
            }

            if ( my $entry = $ei->{$thing} ) {
                delete($eo->{$entry});
            }
        }
    }
}

sub register_object_ids {
    my ( $self, %objects ) = @_;

    my ( $i, $o ) = ( $self->_ids, $self->_objects );

    my $s = $self->current_scope or croak "no open live object scope";

    foreach my $id ( keys %objects ) {
        my $object = $objects{$id};

        croak($object, " is already registered as $o->{$object}{id}")
            if exists($o->{$object}) and $o->{$object}{id} ne $id;;

        croak "An object with the id '$id' is already registered ($i->{$id} != $object)"
            if exists($i->{$id}) and refaddr($i->{$id}) != refaddr($object);

        weaken($i->{$id} = $object);
        $s->push($object);

        my $info = $o->{$objects{$id}} ||= {};

        $info->{id}      = $id;
        $info->{guard} ||= KiokuDB::LiveObjects::Guard->new( $i, $id );
    }
}

sub insert {
    my ( $self, @pairs ) = @_;

    croak "The arguments must be an list of pairs of IDs/Entries to objects"
        unless @pairs % 2 == 0;

    croak "no open live object scope" unless $self->current_scope;

    my ( $o, $i, $eo, $ei ) = ( $self->_objects, $self->_ids, $self->_entry_objects, $self->_entry_ids );

    my @register;
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

        # FIXME bulk this? or will ->insert just get deprecated?
        $self->register_object_ids( $id => $object );

        if ( $entry ) {
            unless ( $ei->{$id} ) {
                $ei->{$id} = $entry;
                $eo->{$entry} = KiokuDB::LiveObjects::Guard->new( $ei, $id );
            }

            # break cycle for passthrough objects
            if ( ref($entry->data) and refaddr($object) == refaddr($entry->data) ) {
                weaken($entry->{data}); # FIXME there should be a MOP way to do this
            }

            my $info = $o->{$object} ||= {};

            $info->{in_storage} = 1;
            $info->{entry} = $entry;
        }
    }
}

sub object_is_in_storage {
    my ( $self, $object ) = @_;

    $self->_objects->{$object}{in_storage};
}

sub insert_entries {
    my ( $self, @entries ) = @_;

    confess "non reference entries: ", join ", ", map { $_ ? $_ : "undef" } @entries if grep { !ref } @entries;

    my $i = $self->_ids;

    @entries = grep { not exists $i->{$_->id} } @entries;

    my @ids = map { $_->id } @entries;

    my $ei = $self->_entry_ids;
    @{ $self->_entry_objects }{@entries} = map { KiokuDB::LiveObjects::Guard->new( $ei, $_ ) } @ids;

    {
        no warnings;
        weaken($_) for @{$ei}{@ids} = @entries;
    }

    return;
}

sub clear {
    my $self = shift;

    foreach my $ent ( values %{ $self->_objects } ) {
        if ( my $guard = $ent->{guard} ) { # sometimes gone in global destruction
            $guard->dismiss;
        }
    }

    foreach my $guard ( values %{ $self->_entry_objects } ) {
        next unless $guard;
        $guard->dismiss;
    }

    # avoid the now needless weaken magic, should be faster
    %{ $self->_objects } = ();
    %{ $self->_ids }     = ();

    %{ $self->_entry_ids } = ();
    %{ $self->_entry_objects } = ();

    $self->_clear_current_scope;
    $self->_known_scopes->clear;
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

=head1 ATTRIBUTES

=over 4

=item clear_leaks

Boolean. Defaults to false.

If true, when the last known scope is removed but some objects are still live
they will be removed from the live object set.

Note that this does B<NOT> prevent leaks (memory cannot be reclaimed), it
merely prevents stale objects from staying loaded.

=item leak_tracker

This is a coderef or object.

If any objects ar eleaked (see C<clear_leaks>) then the this can be used to
report them, or to break the circular structure.

When an object is provided the C<leaked_objects> method is called. The coderef
is simply invoked with the objects as arguments.

Triggered after C<clear_leaks> causes C<clear> to be called.

For example, to break cycles you can use L<Data::Structure::Util>'s
C<circular_off> function:

    use Data::Structure::Util qw(circular_off);

    $dir->live_objects->leak_tracker(sub {
        my @leaked_objects = @_;
        circular_off($_) for @leaked_objects;
    });

=back

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

=item ids_to_objects

=item id_to_object

Given IDs, find the corresponding objects.

=item ids_to_entries

Given IDs, find the corresponding entries.

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

=item remove_scope $scope

Removes a scope from the set of known scopes.

Also calls C<detach_scope>, and calls C<KiokuDB::LiveObjects::Scope/clear> on
the scope itself.

=item detach_scope $scope

Detaches C<$scope> if it's the current scope.

This prevents C<push> from being called on this scope object implicitly
anymore.

=back

=cut
