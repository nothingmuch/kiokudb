#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::StorableHook;
use Moose;

use Scalar::Util qw(reftype);
use Carp qw(croak);

no warnings 'recursion';

# predeclare for namespace::clean;
sub _type ($);
sub _new ($;$);
sub _clear ($);

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::TypeMap::Entry::Std
    KiokuDB::TypeMap::Entry::Std::Expand
);

sub compile_collapse_body {
    my ( $self, $class, @args ) = @_;

    my $attach = $class->can("STORABLE_attach") ? 1 : 0;

    return sub {
        my ( $self, %args ) = @_;

        my $object = $args{object};

        my @type = _type($object);

        my ( $str, @refs ) = $object->STORABLE_freeze(0);

        my $data;

        if ( @refs ) {
            croak sprintf "Freeze cannot return references if %s class is using STORABLE_attach", $class if $attach;

            if ( my @non_refs = grep { not ref } @refs ) {
                croak blessed($object) . "::STORABLE_freeze returned non reference values: @non_refs";
            }

            my @collapsed = $self->visit(@refs);

            foreach my $ref ( @collapsed ) {
                next unless ref($ref) eq 'KiokuDB::Reference';
                next if $self->may_compact($ref);
                $ref = $ref->id; # don't save a bunch of Reference objects when all we need is the ID
            }

            $data = [ @type, $str, @collapsed ],
        } else {
            unless ( $attach ) {
                if ( @type == 1 ) {
                    $data = ( $type[0] . $str );
                } else {
                    $data = [ @type, $str ];
                }
            } else {
                $data = $str;
            }
        }

        return $self->make_entry(
            %args,
            data => $data,
        );
    };
}

sub compile_create {
    my ( $self, $class, @args ) = @_;

    unless ( $class->can("STORABLE_attach") ) {
        # normal form, STORABLE_freeze
        return sub {
            my ( $self, $entry ) = @_;

            my $data = $entry->data;

            my ( $reftype, @args ) = ref $data ? @$data : ( substr($data, 0, 1), substr($data, 1) );

            my $instance;

            if ( ref $args[0] ) {
                my $tied;
                $self->queue_ref(shift(@args), \$tied);
                $instance = _new( $reftype, $tied );
            } else {
                $instance = _new( $reftype );
            }

            bless $instance, $entry->class;
        };
    } else {
        # esotheric STORABLE_attach form
        return sub {
            my ( $self, $entry ) = @_;

            $entry->class->STORABLE_attach( 0, $entry->data ); # FIXME support non ref
        };
    }
}

sub compile_clear {
    my ( $self, $class, @args ) = @_;

    return sub {
        my ( $linker, $instance ) = @_;

        _clear($instance);
    };
}

sub compile_expand_data {
    my ( $self, $class, @args ) = @_;

    unless ( $class->can("STORABLE_attach") ) {
        # normal form, STORABLE_freeze
        return sub {
            my ( $self, $instance, $entry ) = @_;

            my $data = $entry->data;

            my ( $reftype, @args ) = ref $data ? @$data : ( substr($data, 0, 1), substr($data, 1) );

            shift @args if ref $args[0]; # tied

            my ( $str, @refs ) = @args;

            my @inflated;

            foreach my $ref ( @refs ) {
                push @inflated, undef;

                if ( ref $ref ) {
                    $self->inflate_data($ref, \$inflated[-1]);
                } else {
                    $self->queue_ref($ref, \$inflated[-1]);
                }
            }

            $self->queue_finalizer(sub {
                $instance->STORABLE_thaw( 0, $str, @inflated );
            });
        };
    } else {
        # esotheric STORABLE_attach form
        return sub { };
    }
}

sub _type ($) {
    my $obj = shift;

    my $type = reftype($obj);

    if ( $type eq 'SCALAR' or $type eq 'REF' ) {
        if ( my $tied = tied $$obj ) {
            return ( S => $tied );
        } else {
            return 'S';
        }
    } elsif ( $type eq 'HASH' ) {
        if ( my $tied = tied %$obj ) {
            return ( H => $tied );
        } else {
            return 'H';
        }
    } elsif ( $type eq 'ARRAY' ) {
        if ( my $tied = tied @$obj ) {
            return ( A => $tied );
        } else {
            return 'A';
        }
    } else {
		croak sprintf "Unexpected object type (%s)", reftype($obj);
    }
}

sub _new ($;$) {
    my ( $type, $tied ) = @_;

    if ( $type eq 'S' ) {
        my $ref = \( my $x );
        tie $x, "To::Object", $tied if ref $tied;
        return $ref;
    } elsif ( $type eq 'H' ) {
        my $ref = {};
        tie %$ref, "To::Object", $tied if ref $tied;
        return $ref;
    } elsif ( $type eq 'A' ) {
        my $ref = [];
        tie @$ref, "To::Object", $tied if ref $tied;
        return $ref;
    } else {
		croak sprintf "Unexpected object type (%d)", $type;
    }
}

sub _clear ($) {
    my $obj = shift;

    my $type = reftype($obj);

    if ( $type eq 'SCALAR' or $type eq 'REF' ) {
        undef $$obj;
    } elsif ( $type eq 'HASH' ) {
        %$obj = ();
    } elsif ( $type eq 'ARRAY' ) {
        @$obj = ();
    } else {
		croak sprintf "Unexpected object type (%s)", reftype($obj);
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


