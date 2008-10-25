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

    my $self_id = !$self->intrinsic && $meta->does_role("KiokuDB::Role::ID");

    my $method = $self->intrinsic ? "collapse_intrinsic" : "collapse_first_class";

    return sub {
        my $self = shift;

        if ( $self_id ) {
            push @_, id => $_[0]->kiokudb_object_id;
        }

        $self->$method(sub {
            my ( $self, %args ) = @_;

            my %collapsed;

            my $object = $args{object};

            foreach my $attr ( @attrs ) {
                if ( $attr->has_value($object) ) {
                    my $value = $attr->get_value($object);
                    $collapsed{$attr->name} = ref($value) ? $self->visit($value) : $value;
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

    return sub {
        my ( $self, $entry ) = @_;

        my $meta_instance = $meta->get_meta_instance;
        my $instance = $meta_instance->create_instance();

        # note, this is registered *before* any other value expansion, to allow circular refs
        $self->register_object( $entry => $instance );

        my $data = $entry->data;

        foreach my $name ( keys %$data ) {
            my $value = $data->{$name};
            my $attr = $attrs{$name};

            if ( $lazy{$name} and ref($value) eq 'KiokuDB::Reference' ) {
                my $thunk = KiokuDB::Thunk->new( id => $value->id, linker => $self, attr => $attr );
                $meta_instance->set_slot_value($instance, $attr->name, $thunk);
            } else {
                $self->inflate_data($value, \$value) if ref $value;
                $attr->set_value($instance, $value);
            }
        }

        return $instance;
    }
}

sub compile_mappings_immutable {
    my ( $self, $meta ) = @_;
    return (
        $self->compile_collapser($meta),
        $self->compile_expander($meta),
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
    );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
