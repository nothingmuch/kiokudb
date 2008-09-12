#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Normal;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

# FIXME collapser and expaner should both be methods in Class::MOP::Class,
# apart from the visit call

sub compile_mappings {
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

    my @attrs = $meta->compute_all_applicable_attributes;

    return sub {
        my ( $self, %args ) = @_;

        my $object = $args{object};

        my %collapsed;

        foreach my $attr ( @attrs ) {
            if ( $attr->has_value($object) ) {
                my $value = $attr->get_value($object);
                $collapsed{$attr->name} = ref($value) ? $self->visit($value) : $value;
            }
        }

        return \%collapsed;
    }
}

sub compile_expander {
    my ( $self, $meta ) = @_;

    my %attrs;

    foreach my $attr ( $meta->compute_all_applicable_attributes ) {
        $attrs{$attr->name} = $attr;
    }

    return sub {
        my ( $self, $entry ) = @_;

        my $instance = $meta->get_meta_instance->create_instance();

        # note, this is registered *before* any other value expansion, to allow circular refs
        $self->register_object( $entry => $instance );

        my $data = $entry->data;

        foreach my $name ( keys %$data ) {
            my $value = $data->{$name};

            $self->inflate_data($value, \$value) if ref $value;

            $attrs{$name}->set_value($instance, $value);
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
