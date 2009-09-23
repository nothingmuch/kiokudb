#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Set;
use Moose;

no warnings 'recursion';

use KiokuDB::Set::Stored;
use KiokuDB::Set::Deferred;
use KiokuDB::Set::Loaded;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::TypeMap::Entry::Std
    KiokuDB::TypeMap::Entry::Std::Expand
);

has defer => (
    isa => "Bool",
    is  => "ro",
    default => 1,
);

sub compile_collapse_wrapper {
    my ( $self, $method, $class, @args ) = @_;

    my ( $body, @extra ) = $self->compile_collapse_body(@args);

    return sub {
        shift->$method( $body, @extra, @_, class => "KiokuDB::Set::Stored" );
    }
}

sub compile_collapse_body {
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
                $collapser->_buffer->first_class->insert($item); # mark it first class so it doesn't get compacted
            }

            return $collapser->make_entry(
                %args,
                data => \@inner,
            );
        };
    }
}

sub compile_create {
    my ( $self, $class ) = @_;

    if ( $self->defer ) {
        return sub {
            my ( $linker, $entry ) = @_;

            my $members = $entry->data;

            if ( grep { ref } @$members ) {
                return KiokuDB::Set::Loaded->new( set => Set::Object::Weak->new(), _linker => $linker );
            } else {
                return KiokuDB::Set::Deferred->new( set => Set::Object->new( @$members ), _linker => $linker );
            }
        };
    } else {
        return sub {
            my ( $linker, $entry ) = @_;

            return KiokuDB::Set::Loaded->new( set => Set::Object::Weak->new, _linker => $linker );
        };
    }
}

sub compile_clear {
    my ( $self, $class ) = @_;

    sub {
        my ( $linker, $obj ) = @_;
        $obj->_set_ids( Set::Object->new() );
    }
}

sub compile_expand_data {
    my ( $self, $class ) = @_;

    my $defer = $self->defer;

    return sub {
        my ( $linker, $instance, $entry ) = @_;

        my $members = $entry->data;

        my $inner_set = $instance->_objects;

        if ( ref $instance eq 'KiokuDB::Set::Deferred' ) {
            $inner_set->insert( @$members );
        } else {
            foreach my $item ( @$members ) {
                if ( ref $item ) {
                    $linker->inflate_data( $item, \( my $obj ) );
                    $inner_set->insert( $obj );
                } else {
                    # FIXME add partially loaded set support
                    $inner_set->insert( $linker->get_or_load_object($item) );
                }
            }
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
