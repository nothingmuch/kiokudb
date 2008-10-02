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

sub _clone {
    my ( $self, %args ) = @_;
    $args{set} ||= $self->_clone_object_set;
    $self->meta->clone_instance( $self, %args );
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

KiokuDB::Set - 

=head1 SYNOPSIS

	use KiokuDB::Set;

    my $set = KiokuDB::Set->new( ;

    $set->insert($id);

    $set->insert( 

=head1 DESCRIPTION

=cut


