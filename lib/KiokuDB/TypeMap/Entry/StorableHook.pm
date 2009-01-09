#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::StorableHook;
use Moose;

use Scalar::Util qw(reftype);
use Carp qw(croak);

no warnings 'recursion';

# predeclare for namespace::clean;
sub _type ($);
sub _new ($;$);

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

sub compile_mappings {
    my ( $self, $class ) = @_;

    my $attach = $class->can("STORABLE_attach") ? 1 : 0;

    my $freeze = sub {
        my ( $self, %args ) = @_;

        my $object = $args{object};

        my ( $str, @refs ) = $object->STORABLE_freeze(0);

        if ( @refs ) {
            croak sprintf "Freeze cannot return references if %s class is using STORABLE_attach", $class if $attach;
            @refs = $self->visit(@refs);

            foreach my $ref ( @refs ) {
                # they may be intrinsic in which case they aren't refs
                $ref = $ref->id if ref($ref) eq 'KiokuDB::Reference';
            }
        }

        unless ( $attach ) {
            return [ _type($object), $str, @refs ];
        } else {
            # return $str
            return $str;
        }
    };

    unless ( $attach ) {
        # normal form, STORABLE_freeze
        return ( $freeze, sub {
            my ( $self, $entry ) = @_;

            my ( $reftype, @args ) = @{ $entry->data };

            my $instance;

            if ( ref $args[0] ) {
                my $tied;
                $self->inflate_data(shift(@args), \$tied);
                $instance = _new( $reftype, $tied );
            } else {
                $instance = _new( $reftype );
            }

            bless $instance, $entry->class;

            # note, this is registered *before* any other value expansion, to allow circular refs
            $self->register_object( $entry => $instance );


            my ( $str, @refs ) = @args;

            my @inflated;

            foreach my $ref ( @refs ) {
                push @inflated, undef;
                $ref = KiokuDB::Reference->new( id => $ref ) unless ref $ref;
                $self->inflate_data($ref, \$inflated[-1]);
            }

            $self->queue_finalizer(sub {
                $instance->STORABLE_thaw( 0, $str, @inflated);
            });

            return $instance;
        });
    } else {
        # esotheric STORABLE_attach form
        return ( $freeze, sub {
            my ( $self, $entry ) = @_;

            $entry->class->STORABLE_attach( 0, $entry->data ); # FIXME support non ref
        });
    }
}

sub _type ($) {
    my $obj = shift;

    my $type = reftype($obj);

    if ( $type eq 'SCALAR' or $type eq 'REF' ) {
        if ( my $tied = tied $$obj ) {
            return ( $type => $tied );
        }
    } elsif ( $type eq 'HASH' ) {
        if ( my $tied = tied %$obj ) {
            return ( $type => $tied );
        }
    } elsif ( $type eq 'ARRAY' ) {
        if ( my $tied = tied @$obj ) {
            return ( $type => $tied );
        }
    } else {
		croak sprintf "Unexpected object type (%s)", $type;
    }

    return $type;
}

sub _new ($;$) {
    my ( $type, $tied ) = @_;

    if ( $type eq 'SCALAR' ) {
        my $ref = \( my $x );
        tie $x, "To::Object", $tied if ref $tied;
        return $ref;
    } elsif ( $type eq 'HASH' ) {
        my $ref = {};
        tie %$ref, "To::Object", $tied if ref $tied;
        return $ref;
    } elsif ( $type eq 'ARRAY' ) {
        my $ref = [];
        tie @$ref, "To::Object", $tied if ref $tied;
        return $ref;
    } else {
		croak sprintf "Unexpected object type (%d)", $type;
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::StorableHook - Reuse existing L<Storable> hooks for
L<KiokuDB> storage.

=head1 SYNOPSIS

	use KiokuDB::TypeMap::Entry::StorableHook;

=head1 DESCRIPTION

=cut


