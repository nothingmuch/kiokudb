#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::MOP;
use Moose;

use KiokuDB::Thunk;

no warnings 'recursion';

use namespace::clean -except => 'meta';

# not Std because of the ID role support needing to happen early
has intrinsic => (
    isa => "Bool",
    is  => "ro",
    default => 0,
);

# FIXME collapser and expaner should both be methods in Class::MOP::Class,
# apart from the visit call

sub compile {
    my ( $self, $class ) = @_;

    my $meta = Class::MOP::get_metaclass_by_name($class);

    if ( $meta->is_immutable ) {
        $self->compile_mappings_immutable($meta);
    } else {
        $self->compile_mappings_mutable($meta);
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

    my $method = $self->intrinsic ? "collapse_intrinsic" : "collapse_first_class";

    return sub {
        my $self = shift;

        $self->$method(sub {
            my ( $self, %args ) = @_;

            my %collapsed;

            my $object = $args{object};

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

            return \%collapsed;
        }, @_);
    }
}

sub compile_expander {
    my ( $self, $meta ) = @_;

    my ( %attrs, %lazy );

    my @attrs = grep {
        !$_->does('MooseX::Storage::Meta::Attribute::Trait::DoNotSerialize')
    } $meta->compute_all_applicable_attributes;

    foreach my $attr ( @attrs ) {
        $attrs{$attr->name} = $attr;
        $lazy{$attr->name}  = $attr->does("KiokuDB::Meta::Attribute::Lazy");
    }

    my $meta_instance = $meta->get_meta_instance;

    return sub {
        my ( $self, $entry ) = @_;

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

        push @{ $self->_deferred }, sub {
            foreach my $pair ( @values ) {
                my ( $attr, $value ) = @$pair;
                $attr->set_value($instance, $value);
            }
        };

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
    my ( $self, $meta ) = @_;
    return (
        $self->compile_collapser($meta),
        $self->compile_expander($meta),
        $self->compile_id($meta),
    );
}

sub compile_mappings_mutable {
    my ( $self, $meta ) = @_;

    #warn "Mutable: " . $meta->name;

    return (
        sub {
            my $collapser = $self->compile_collapser($meta);
            shift->$collapser(@_);
        },
        sub {
            my $expander = $self->compile_expander($meta);
            shift->$expander(@_);
        },
        sub {
            my $id = $self->compile_id($meta);
            shift->$id(@_);
        },
    );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
