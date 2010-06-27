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

use Moose::Util::TypeConstraints;

use namespace::clean -except => 'meta';

coerce __PACKAGE__, from "HashRef", via { __PACKAGE__->new($_) };

has clear_leaks => (
    isa => "Bool",
    is  => "rw",
);

has cache => (
    isa => "Cache::Ref",
    is  => "ro",
);

has leak_tracker => (
    isa => "CodeRef|Object",
    is  => "rw",
    clearer => "clear_leak_tracker",
);

has keep_entries => (
    isa => "Bool",
    is  => "ro",
    default => 1,
);

has [qw(_objects _entries _object_entries)] => (
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
);

sub _id_info {
    my ( $self, @ids ) = @_;

    no warnings 'uninitialized'; # @ids can contain undefs

    if ( @ids == 1 ) {
        return $self->_ids->{$ids[0]};
    } else {
        return @{ $self->_ids }{@ids};
    }
}

sub _vivify_id_info {
    my ( $self, $id ) = @_;

    my $info;

    my $i = $self->_ids;

    unless ( $info = $i->{$id} ) {
        $info = { guard => KiokuDB::LiveObjects::Guard->new( $i, $id ) };
        weaken( $i->{$id} = $info );
    }

    return $info;
}

sub id_to_object {
    my ( $self, $id ) = @_;

    if ( my $c = $self->cache ) {
        $c->hit($id);
    }

    if ( my $data = $self->_id_info($id) ) {
        return $data->{object};
    }
}

sub ids_to_objects {
    my ( $self, @ids ) = @_;

    if ( my $c = $self->cache ) {
        $c->hit(@ids);
    }

    map { $_ && $_->{object} } $self->_id_info(@ids);
}

sub known_ids {
    keys %{ shift->_ids };
}

sub live_ids {
    my $self = shift;

    grep { ref $self->_id_info($_)->{object} } $self->known_ids;
}

sub live_objects {
    grep { ref } map { $_->{object} } values %{ shift->_ids };
}

sub id_to_entry {
    my ( $self, $id ) = @_;

    if ( my $data = $self->_id_info($id) ) {
        return $data->{entry};
    }

    return undef;
}

sub ids_to_entries {
    my ( $self, @ids ) = @_;

    return $self->id_to_entry($ids[0]) if @ids == 1;

    map { $_ && $_->{entry} } $self->_id_info(@ids);
}

sub loaded_ids {
    my $self = shift;

    grep { $self->_id_info($_)->{entry} } $self->known_ids;
}

sub live_entries {
    grep { ref } map { $_->{entry} } values %{ shift->_ids };
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
        $self->check_leaks;
    }
}

sub check_leaks {
    my $self = shift;

    return if $self->_known_scopes->size;

    if ( my @still_live = grep { defined } $self->live_objects ) {
        # immortal objects are still live but not considered leaks
        my $o = $self->_objects;
        my @leaked = grep {
            my $i = $o->{$_};
            not($i->{immortal} or $i->{cache})
        } @still_live;

        if ( $self->clear_leaks ) {
            $self->clear;
        }

        if ( my $tracker = $self->leak_tracker and @leaked ) {
            if ( ref($tracker) eq 'CODE' ) {
                $tracker->(@leaked);
            } else {
                $tracker->leaked_objects(@leaked);
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

    return unless $self->keep_entries;

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

    map { $_ && $_->{guard}->key } @{ $self->_objects }{@objects};
}

sub object_to_id {
    my ( $self, $obj ) = @_;

    if ( my $info = $self->_objects->{$obj} ){
        return $info->{guard}->key;
    }

    return undef;
}

sub objects_to_entries {
    my ( $self, @objects ) = @_;

    return $self->ids_to_entries( $self->objects_to_ids(@objects) );
}

sub object_to_entry {
    my ( $self, $obj ) = @_;

    return $self->id_to_entry( $self->object_to_id($obj) || return );
}

sub id_in_root_set {
    my ( $self, $id ) = @_;

    if ( my $data = $self->_id_info($id) ) {
        return $data->{root};
    }

    return undef;
}

sub id_in_storage {
    my ( $self, $id ) = @_;

    if ( my $data = $self->_id_info($id) ) {
        return $data->{in_storage};
    }

    return undef;
}


sub object_in_storage {
    my ( $self, $object ) = @_;

    $self->id_in_storage( $self->object_to_id($object) || return );
}

sub update_object_entry {
    my ( $self, $object, $entry, %args ) = @_;


    my $s = $self->current_scope or croak "no open live object scope";

    my $info = $self->_objects->{$object} or croak "Object not yet registered";
    $self->_entries->{$entry} = $info;

    @{$info}{keys %args} = values %args;
    weaken($info->{entry} = $entry);

    if ( $self->keep_entries ) {
        $self->_object_entries->{$object} = $entry;

        if ( $args{in_storage} and my $txs = $self->txn_scope ) {
            $txs->push($entry);
        }
    }

    # break cycle for passthrough objects
    if ( ref($entry->data) and refaddr($object) == refaddr($entry->data) ) {
        weaken($entry->{data}); # FIXME there should be a MOP way to do this
    }
}

sub register_object {
    my ( $self, $id, $object, %args ) = @_;

    my $s = $self->current_scope or croak "no open live object scope";

    croak($object, " is not a reference") unless ref($object);
    croak($object, " is an entry") if blessed($object) && $object->isa("KiokuDB::Entry");

    if ( my $id = $self->object_to_id($object) ) {
        croak($object, " is already registered as $id")
    }

    my $info = $self->_vivify_id_info($id);

    if ( ref $info->{object} ) {
        croak "An object with the id '$id' is already registered ($info->{object} != $object)"
    }

    $self->_objects->{$object} = $info;

    weaken($info->{object} = $object);

    if ( my $entry = $info->{entry} ) {
        # break cycle for passthrough objects
        if ( ref($entry->data) and refaddr($object) == refaddr($entry->data) ) {
            weaken($entry->{data}); # FIXME there should be a MOP way to do this
        }

        if ( $self->keep_entries ) {
            $self->_object_entries->{$object} = $entry;
        }
    }

    @{$info}{keys %args} = values %args;

    if ( $args{cache} and my $c = $self->cache ) {
        $c->set( $id => $object );
    }

    $s->push($object);
}

sub register_entry {
    my ( $self, $id, $entry, %args ) = @_;

    my $info = $self->_vivify_id_info($id);

    $self->_entries->{$entry} = $info;

    confess "$entry" unless $entry->isa("KiokuDB::Entry");
    @{$info}{keys %args, 'root'} = ( values %args, $entry->root );

    weaken($info->{entry} = $entry);

    if ( $args{in_storage} and $self->keep_entries and my $txs = $self->txn_scope ) {
        $txs->push($entry);
    }
}

sub insert {
    my ( $self, @pairs ) = @_;

    croak "The arguments must be an list of pairs of IDs/Entries to objects"
        unless @pairs % 2 == 0;

    croak "no open live object scope" unless $self->current_scope;

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

        if ( $entry ) {
            $self->register_entry( $id => $entry, in_storage => 1 );
            $self->register_object( $id => $object );
        } else {
            $self->register_object( $id => $object );
        }
    }
}

sub update_entries {
    my ( $self, @pairs ) = @_;
    my @entries;

    while ( @pairs ) {
        my ( $object, $entry ) = splice @pairs, 0, 2;

        $self->register_entry( $entry->id => $entry, in_storage => 1 );

        unless ( $self->object_to_id($object) ) {
            $self->register_object( $entry->id => $object );
        } else {
            $self->update_object_entry( $object, $entry );
        }
    }

    return;
}

sub rollback_entries {
    my ( $self, @entries ) = @_;

    foreach my $entry ( reverse @entries ) {
        my $info = $self->_id_info($entry->id);

        if ( my $prev = $entry->prev ) {
            weaken($info->{entry} = $prev);
        } else {
            delete $info->{entry};
        }
    }
}

sub remove {
    my ( $self, @stuff ) = @_;

    my ( $i, $o, $e, $oe ) = ( $self->_ids, $self->_objects, $self->_entries, $self->_object_entries );

    while ( @stuff ) {
        my $thing = shift @stuff;

        if ( ref $thing ) {
            # FIXME make this a bit less zealous?
            my $info;
            if ( $info = delete $o->{$thing} ) {
                delete $info->{object};
                delete $oe->{$thing};
                push @stuff, $info->{entry} if $info->{entry};
            } elsif ( $info = delete $e->{$thing} ) {
                delete $info->{entry};
                push @stuff, $info->{object} if ref $info->{object};
            }
        } else {
            my $info = delete $i->{$thing};
            push @stuff, grep { ref } delete @{$info}{qw(entry object)};
        }
    }
}

sub clear {
    my $self = shift;

    # don't waste too much time in DESTROY
    $_->{guard}->dismiss for values %{ $self->_ids };

    %{ $self->_ids } = ();
    %{ $self->_objects } = ();
    %{ $self->_object_entries } = ();
    %{ $self->_entries } = ();

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

=item keep_entries

B<EXPERIMENTAL>

When true (the default), L<KiokuDB::Entries> loaded from the backend or created
by the collapser are kept around.

This results in a considerable memory overhead, so it's no longer required.

=back

=head1 METHODS

=over 4

=item insert

Takes pairs, id or entry as the key, and object as the value, registering the
objects.

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
