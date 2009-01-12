#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Set;
use Moose;

no warnings 'recursion';

use KiokuDB::Set::Stored;
use KiokuDB::Set::Deferred;
use KiokuDB::Set::Loaded;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry);

has defer => (
    isa => "Bool",
    is  => "ro",
    default => 1,
);

has intrinsic => (
    isa => "Bool",
    is  => "ro",
    default => 0,
);

sub compile {
    my ( $self, @args ) = @_;

    my $collapse = $self->intrinsic ? $self->_compile_collapse_intrinsic(@args) : $self->_compile_collapse_first_class(@args);

    my $expand = $self->_compile_expand(@args);

    return ( $collapse, $expand, "generate_uuid" );
}

sub _compile_collapse_intrinsic {
    my ( $self, $class ) = @_;

    my $collapse = $self->_compile_collapse($class);

    return sub {
        shift->collapse_intrinsic( $collapse, @_, class => "KiokuDB::Set::Stored" );
    }
}

sub _compile_collapse_first_class {
    my ( $self, $class ) = @_;

    my $collapse = $self->_compile_collapse($class);

    return sub {
        shift->collapse_first_class( $collapse, @_, class => "KiokuDB::Set::Stored" );
    }
}

sub _compile_collapse {
    my ( $self, $class ) = @_;

    if ( $class->isa("KiokuDB::Set::Deferred") ) {
        # if it's deferred we just return the IDs
        return sub {
            my ( $collapser, %args ) = @_;

            return $collapser->make_entry(
                %args,
                data => [ $args{object}->_objects->members ],
            );
        };
    } else {
        # otherwise we collapse the objects recursively
        return sub {
            my ( $collapser, %args ) = @_;

            my @inner = $collapser->visit($args{object}->_objects->members);

            # we flatten references to just IDs
            foreach my $item ( @inner ) {
                $item = $item->id if ref($item) eq 'KiokuDB::Reference';
                $collapser->_first_class->{$item} = undef; # mark it first class so it doesn't get compacted
            }

            return $collapser->make_entry(
                %args,
                data => \@inner,
            );
        };
    }
}

sub _compile_expand {
    my ( $self, $class ) = @_;

    my $defer = $self->defer;

    return sub {
        my ( $linker, $entry ) = @_;

        my $members = $entry->data;

        if ( !$defer or grep { ref } @$members ) {
            my $inner_set = Set::Object::Weak->new;
            # inflate the set
            my $set = KiokuDB::Set::Loaded->new( set => $inner_set, _linker => $linker );

            $linker->register_object( $entry => $set );

            foreach my $item ( @$members ) {
                if ( ref $item ) {
                    $linker->inflate_data( $item, \( my $obj ) );
                    $inner_set->insert( $obj );
                } else {
                    # FIXME add partially loaded set support
                    $inner_set->insert( $linker->get_or_load_object($item) );
                }
            }

            return $set;
        } else {
            # just IDs, no inflation
            my $set = KiokuDB::Set::Deferred->new( set => Set::Object->new( @$members ), _linker => $linker );
            $linker->register_object( $entry => $set );
            return $set;
        }
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::Set - A typemap entry for L<KiokuDB::Set>s

=head1 DESCRIPTION

This is an internal typemap entry that handles L<KiokuDB::Set> objects of
various flavours.

You shouldn't need to use it directly, as the default typemap will contain an
entry for it.
