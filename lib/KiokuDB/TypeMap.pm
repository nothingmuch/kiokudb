#!/usr/bin/perl

package KiokuDB::TypeMap;
use Moose;

use Carp qw(croak);
use Try::Tiny;

use KiokuDB::TypeMap::Entry;
use KiokuDB::TypeMap::Entry::Alias;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Role::TypeMap);

has [qw(entries isa_entries)] => (
    #isa => "HashRef[KiokuDB::TypeMap::Entry|KiokuDB::TypeMap::Entry::Alias]", # dog slow regex
    is  => "ro",
    lazy_build => 1,
);

sub _build_entries { +{} }
sub _build_isa_entries { +{} }

has [qw(all_entries all_isa_entries)] => (
    #isa => "HashRef[KiokuDB::TypeMap::Entry|KiokuDB::TypeMap::Entry::Alias]", # dog slow regex
    is  => "ro",
    lazy_build => 1,
);

has all_isa_entry_classes => (
    isa => "ArrayRef[Str]",
    is  => "ro",
    lazy_build => 1,
);

has includes => (
    isa => "ArrayRef[KiokuDB::TypeMap]",
    is  => "ro",
    lazy_build => 1,
);

sub _build_includes { [] }

my %loaded;

sub resolve {
    my ( $self, $class ) = @_;

    # if we're linking the class might not be loaded yet
    unless ( $loaded{$class}++ ) {
        ( my $pmfile = $class . ".pm" ) =~ s{::}{/}g;

        try {
            require $pmfile;
        } catch {
            croak $_ unless /^Can't locate \Q$pmfile\E in \@INC/;
        };
    }

    # if this is an anonymous class, redo the lookup using a single named
    # ancestor
    if ( my $meta = Class::MOP::get_metaclass_by_name($class) ) {
        if ( $meta->is_anon_class ) {
            my $ancestor = $meta;

            search: {
                my @super = $ancestor->superclasses;

                if ( @super == 1 ) {
                    $ancestor = Class::MOP::get_metaclass_by_name($super[0]);
                    if ( $ancestor->is_anon_class ) {
                        redo search;
                    }
                } else {
                    croak "Cannot resolve anonymous class with multiple inheritence: $class";
                }
            }

            return $self->resolve( $ancestor->name );
        }
    }


    if ( my $entry = $self->all_entries->{$class} || $self->all_isa_entries->{$class} ) {
        return $self->resolve_entry( $entry );
    } else {
        foreach my $superclass ( @{ $self->all_isa_entry_classes } ) {
            if ( $class->isa($superclass) ) {
                return $self->resolve_entry( $self->all_isa_entries->{$superclass} );
            }
        }
    }

    return;
}

sub resolve_entry {
    my ( $self, $entry ) = @_;

    if ( $entry->isa("KiokuDB::TypeMap::Entry::Alias") ) {
        return $self->resolve( $entry->to );
    } else {
        return $entry;
    }
}

sub BUILD {
    my $self = shift;

    # verify that there are no conflicting internal definitions
    my $reg = $self->entries;
    foreach my $key ( keys %{ $self->isa_entries } ) {
        if ( exists $reg->{$key} ) {
            croak "isa entry $key already present in plain entries";
        }
    }

    # Verify that there are no conflicts between the includesd type maps
    my %seen;
    foreach my $map ( @{ $self->includes } ) {
        foreach my $key ( keys %{ $map->all_entries } ) {
            if ( $seen{$key} ) {
                croak "entry $key found in $map conflicts with $seen{$key}";
            }

            $seen{$key} = $map;
        }

        foreach my $key ( keys %{ $map->all_isa_entries } ) {
            if ( $seen{$key} ) {
                croak "isa entry $key found in $map conflicts with $seen{$key}";
            }

            $seen{$key} = $map;
        }
    }
}

sub _build_all_entries {
    my $self = shift;

    return {
        map { %$_ } (
            ( map { $_->all_entries } @{ $self->includes } ),
            $self->entries,
        ),
    };
}

sub _build_all_isa_entries {
    my $self = shift;

    return {
        map { %$_ } (
            ( map { $_->all_isa_entries } @{ $self->includes } ),
            $self->isa_entries,
        ),
    };
}

sub _build_all_isa_entry_classes {
    my $self = shift;

    return [
        sort { !$a->isa($b) <=> !$b->isa($a) } # least derived first
        keys %{ $self->all_isa_entries }
    ];
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap - Class to collapsing/expanding logic.

=head1 SYNOPSIS

    use KiokuDB::TypeMap;

    KiokuDB::TypeMap->new(
        entries => {
            'Foo' => KiokuDB::TypeMap::Entry::Naive->new,
        },
        isa_entries => {
            'My::Class' => KiokuDB::TypeMap::Entry::Naive->new,
        },
        includes => [
            $typemap_foo,
            $typemap_bar,
        ],
    );

=head1 DESCRIPTION

The L<KiokuDB> typemap maps classes to L<KiokuDB::TypeMap::Entry> objects.

The mapping is by class, and entries can be keyed normally (using
C<ref $object> equality) or by filtering on C<< $object->isa($class) >>
(C<isa_entries>).

=head1 ATTRIBUTES

=over 4

=item entries

A hash of normal entries.

=item isa_entries

A hash of C<< $object->isa >> based entries.

=item includes

A list of parent typemaps to inherit entries from.

=back

=head1 METHODS

=over 4

=item resolve $class

Given a class returns the C<KiokuDB::TypeMap::Entry> object corresponding tot
hat class.

Called by L<KiokuDB::TypeMap::Resover>

=item resolve_entry $entry

If the entry is an alias, it will be resolved recursively, and simply returned
otherwise.

=item all_entries

Returns the merged C<entries> from this typemap and all the included typemaps.

=item all_isa_entries

Returns the merged C<isa_entries> from this typemap and all the included
typemaps.

=item all_isa_entry_classes

An array reference of all the classes in C<all_isa_entries>, sorted from least
derived to most derived.

=back
