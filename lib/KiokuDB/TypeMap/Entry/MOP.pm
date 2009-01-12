#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::MOP;
use Moose;

use Carp qw(croak);

use KiokuDB::Thunk;

no warnings 'recursion';

use namespace::clean -except => 'meta';

# not Std because of the ID role support needing to happen early
has intrinsic => (
    isa => "Bool",
    is  => "ro",
    predicate => "has_intrinsic",
);

# FIXME collapser and expaner should both be methods in Class::MOP::Class,
# apart from the visit call

sub compile {
    my ( $self, $class, @args ) = @_;

    my $meta = Class::MOP::get_metaclass_by_name($class);

    if ( $meta->is_immutable || $meta->is_anon_class ) {
        $self->compile_mappings_immutable($meta, @args);
    } else {
        $self->compile_mappings_mutable($meta, @args);
    }
}

sub compile_collapser {
    my ( $self, $meta ) = @_;

    my @attrs = grep {
        !$_->does('MooseX::Storage::Meta::Attribute::Trait::DoNotSerialize')
    } $meta->compute_all_applicable_attributes;

    my %lazy;
    foreach my $attr ( @attrs ) {
        $lazy{$attr->name}  = $attr->does("KiokuDB::Meta::Attribute::Lazy");
    }

    my $meta_instance = $meta->get_meta_instance;

    my $method;

    if ( $self->has_intrinsic ) {
        $method = $self->intrinsic ? "collapse_intrinsic" : "collapse_first_class";
    } elsif ( $meta->does_role("KiokuDB::Role::Intrinsic") ) {
        $method = "collapse_intrinsic";
    } else {
        $method = "collapse_first_class";
    }

    my %attrs;

    if ( $meta->is_anon_class ) {

        # FIXME ancestral roles all the way up to first non anon ancestor,
        # at least check for additional attributes or other metadata which we
        # should probably error on if anything

        my $ancestor = $meta;

        search: {
            my @super = $ancestor->superclasses;

            if ( @super == 1 ) {
                $ancestor = Class::MOP::get_metaclass_by_name($super[0]);
                if ( $ancestor->is_anon_class ) {
                    redo search;
                }
            } else {
                croak "Cannot resolve anonymous class with multiple inheritence: " . $meta->name;
            }
        }

        %attrs = (
            class => $ancestor->name,
            class_meta => {
                roles => [ map { $_->name } @{ $meta->roles } ],
            },
        );
    }

    my $immutable = $meta->does_role("KiokuDB::Role::Immutable");
    my $content_id = $meta->does_role("KiokuDB::Role::ID::Content");

    return sub {
        my ( $self, $obj, @args ) = @_;

        $self->$method(sub {
            my ( $self, %args ) = @_;

            my $object = $args{object};

            if ( $immutable ) {
                if ( my $prev = $self->live_objects->object_to_entry($object) ){
                    return $self->make_skip_entry( %args, prev => $prev );
                } elsif ( $content_id ) {
                    if ( ($self->backend->exists($args{id}))[0] ) { # exists works in list context
                        return $self->make_skip_entry(%args);
                    }
                }
            }

            my %collapsed;

            attr: foreach my $attr ( @attrs ) {
                my $name = $attr->name;
                if ( $attr->has_value($object) ) {
                    if ( $lazy{$name} ) {
                        my $value = $meta_instance->Class::MOP::Instance::get_slot_value($object, $name); # FIXME fix KiokuDB::Meta::Instance to allow fetching thunk

                        if ( ref $value eq 'KiokuDB::Thunk' ) {
                            $collapsed{$name} = KiokuDB::Reference->new( id => $value->id );
                            next attr;
                        }
                    }

                    my $value = $attr->get_value($object);
                    $collapsed{$name} = ref($value) ? $self->visit($value) : $value;
                }
            }

            return $self->make_entry(
                %args,
                data => \%collapsed,
            );
        }, $obj, %attrs, @args);
    }
}

sub compile_expander {
    my ( $self, $meta, $resolver ) = @_;

    my ( %attrs, %lazy );

    my @attrs = grep {
        !$_->does('MooseX::Storage::Meta::Attribute::Trait::DoNotSerialize')
    } $meta->compute_all_applicable_attributes;

    foreach my $attr ( @attrs ) {
        $attrs{$attr->name} = $attr;
        $lazy{$attr->name}  = $attr->does("KiokuDB::Meta::Attribute::Lazy");
    }

    my $meta_instance = $meta->get_meta_instance;

    my $typemap_entry = $self;

    my $anon = $meta->is_anon_class;

    return sub {
        my ( $self, $entry, @args ) = @_;

        if ( $entry->has_class_meta and !$anon ) {
            # the entry is for an anonymous subclass of this class, we need to
            # compile that entry and short circuit to it. if $anon is true then
            # we're already compiled, and the class_meta is already handled
            my $anon_meta = $meta->create_anon_class(
                cache => 1,
                superclasses => [ $entry->class ],
                %{ $entry->class_meta },
            );

            my $anon_class = $anon_meta->name;

            unless ( $resolver->resolved($anon_class) ) {
                $resolver->compile_entry($anon_class, $typemap_entry);
            }

            my $method = $resolver->expand_method($anon_class);
            return $self->$method($entry, @args);
        }


        my $instance = $meta_instance->create_instance();

        # note, this is registered *before* any other value expansion, to allow circular refs
        $self->register_object( $entry => $instance );

        my $data = $entry->data;

        my @values;

        foreach my $name ( keys %$data ) {
            my $value = $data->{$name};
            my $attr = $attrs{$name};

            if ( ref $value ) {
                if ( $lazy{$name} and ref($value) eq 'KiokuDB::Reference' ) {
                    my $thunk = KiokuDB::Thunk->new( id => $value->id, linker => $self, attr => $attr );
                    $meta_instance->set_slot_value($instance, $attr->name, $thunk); # FIXME low level variant of $attr->set_value
                } else {
                    my @pair = ( $attr, undef );

                    $self->inflate_data($value, \$pair[1]) if ref $value;
                    push @values, \@pair;
                }
            } else {
                $attr->set_value($instance, $value);
            }
        }

        $self->queue_finalizer(sub {
            foreach my $pair ( @values ) {
                my ( $attr, $value ) = @$pair;
                $attr->set_value($instance, $value);
            }
        });

        return $instance;
    }
}

sub compile_id {
    my ( $self, $meta ) = @_;

    if ( $meta->does_role("KiokuDB::Role::ID") ) {
        return sub {
            my ( $self, $object ) = @_;
            return $object->kiokudb_object_id;
        }
    } else {
        return "generate_uuid";
    }
}

sub compile_mappings_immutable {
    my ( $self, @args ) = @_;
    return (
        $self->compile_collapser(@args),
        $self->compile_expander(@args),
        $self->compile_id(@args),
    );
}

sub compile_mappings_mutable {
    my ( $self, @args ) = @_;

    #warn "Mutable: " . $meta->name;

    return (
        sub {
            my $collapser = $self->compile_collapser(@args);
            shift->$collapser(@_);
        },
        sub {
            my $expander = $self->compile_expander(@args);
            shift->$expander(@_);
        },
        sub {
            my $id = $self->compile_id(@args);
            shift->$id(@_);
        },
    );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::MOP - A L<KiokuDB::TypeMap> entry for objects with a
metaclass.

=head1 SYNOPSIS

    KiokuDB::TypeMap::Entry::MOP->new()

=head1 DESCRIPTION

This typemap entry handles collapsing and expanding of L<Moose> based objects.

It supports anonymous classes with runtime roles, the L<KiokuDB::Role::ID> role.

Code for immutable classes is cached and performs several orders of magnitude
better, so make use of L<Moose::Meta::Class/make_immutable>.

=head1 ATTRIBUTES

=over 4

=item intrinsic

If true the object will be collapsed as part of its parent, without an ID.

=back
