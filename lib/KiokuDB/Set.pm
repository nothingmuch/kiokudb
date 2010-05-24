#!/usr/bin/perl

package KiokuDB::Set;
use Moose::Role 'requires', 'has' => { -as => "attr" }; # need a 'has' method

use Moose::Util::TypeConstraints;

use Set::Object;

use namespace::clean -except => "meta";

coerce( __PACKAGE__,
    from ArrayRef => via {
        require KiokuDB::Set::Transient;
        KiokuDB::Set::Transient->new( set => Set::Object->new( @$_ ) ),
    },
);

requires qw(
    includes
    members
    insert
    remove
);

attr _objects => (
    isa => "Set::Object",
    is  => "ro",
    init_arg => "set",
    writer   => "_set_objects",
    handles  => [qw(clear size is_weak weaken strengthen is_null)],
    default  => sub { Set::Object->new },
);

sub clone {
    my ( $self, @args ) = @_;
    $self->_clone(@args);
}

sub _clone {
    my ( $self, %args ) = @_;
    $args{set} ||= $self->_clone_object_set;
    $self->meta->clone_object( $self, %args );
}

sub _clone_object_set {
    my $self = shift;
    my $set = $self->_objects;
    ( ref $set )->new( $set->members );
}

sub delete { shift->remove(@_) }

sub elements { shift->members }

sub has { (shift)->includes(@_) }
sub contains { (shift)->includes(@_) }
sub element { (shift)->member(@_) }
sub member {
    my $self = shift;
    my $item = shift;
    return ( $self->includes($item) ?
        $item : undef );
}

sub _apply {
    my ( $self, $method, @sets ) = @_;

    my @real_sets;

    foreach my $set ( @sets ) {
        if ( my $meth = $set->can("_load_all") ) {
            $set->$meth;
        }

        if ( my $inner = $set->can("_objects") ) {
            push @real_sets, $set->$inner;
        } elsif ( $set->isa("Set::Object") ) {
            push @real_sets, $set;
        } else {
            die "Bad set interaction: $self with $set";
        }
    }

    $self->_clone( set => $self->_objects->$method( @real_sets ) );
}

# we weed out empty sets so that they don't trigger loading of deferred sets

sub union {
    if ( my @sets = grep { $_->size } @_ ) {
        my $self = shift @sets;
        return $self->_apply( union => @sets );
    } else {
        my $self = shift;
        return $self->_clone
    }
}

sub intersection {
    my ( $self, @sets ) = @_;

    if ( grep { $_->size == 0 } $self, @sets ) {
        return $self->_clone;
    } else {
        $self->_apply( intersection => @sets );
    }
}

sub subset {
    my ( $self, $other ) = @_;

    return if $other->size < $self->size;
    return 1 if $self->size == 0;

    $self->_apply( subset => $other )
}

sub difference {
    my ( $self, $other ) = @_;

    if ( $other->size == 0 ) {
        return $self->_clone;
    } else {
        $self->_apply( difference => $other );
    }
}

sub equal {
    my ( $self, $other ) = @_;

    return 1 if $self->size == 0 and $other->size == 0;
    return if $self->size != 0 and $other->size != 0;

    $self->_apply( equal => $other )
}

sub not_equal {
    my ( $self, $other ) = @_;
    not $self->equal($other);
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set - L<Set::Object> wrapper for KiokuDB with lazy loading.

=head1 SYNOPSIS

    use KiokuDB::Util qw(set);

    my $set = set(); # KiokuDB::Set::Transient

    $set->insert($object);

    warn $set->size;

    my $id = $dir->store( $set );

=head1 DESCRIPTION

This role defines the API implemented by L<KiokuDB::Set::Transient>,
L<KiokuDB::Set::Deferred>, and L<KiokuDB::Set::Loaded>.

These three classes are modeled after L<Set::Object>, but have implementation
details specific to L<KiokuDB>.

=head2 Transient Sets

Transient sets are in memory, they are sets that have been constructed by the
user for subsequent insertion into storage.

When you create a new set, this is what you should use.

L<KiokuDB::Util> provides convenience functions (L<KiokuDB::Util/set> and
L<KiokuDB::Util/weak_set>) to construct transient sets concisely.

=head2 Deferred Sets

When a set is loaded from the backend, it is deferred by default. This means
that the objects inside the set are not yet loaded, and will be fetched only as
needed.

When set members are needed, the set is upgraded in place into a
L<KiokuDB::Set::Loaded> object.

=head2 Loaded Sets

This is the result of vivifying the members of a deferred set, and is similar
to transient sets in implemenation.

=cut

