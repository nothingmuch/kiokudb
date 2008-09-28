#!/usr/bin/perl

package KiokuDB::TypeMap;
use Moose;

use Carp qw(croak);

use KiokuDB::TypeMap::Entry;
use KiokuDB::TypeMap::Entry::Alias;

use namespace::clean -except => 'meta';

has [qw(entries isa_entries)] => (
    #isa => "HashRef[KiokuDB::TypeMap::Entry|KiokuDB::TypeMap::Entry::Alias]", # dog slow regex
    is  => "ro",
    default => sub { return {} },
);

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
    default => sub { [] },
);

sub resolve {
    my ( $self, $class ) = @_; # FIXME resolve by object?

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
