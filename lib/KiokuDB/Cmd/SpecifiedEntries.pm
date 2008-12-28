#!/usr/bin/perl

package KiokuDB::Cmd::SpecifiedEntries;
use Moose::Role;

use Data::Stream::Bulk::Util qw(bulk);

use namespace::clean -except => 'meta';

#with qw(KiokuDB::Cmd::WithDSN); # attributes don't recompose well
#requires 'backend';

has ids => (
    does => "ArrayRef[Str]",
    is   => "ro",
    predicate => "has_ids",
    documentation => "dump only these entries (can be specified multiple times)",
);

has entries => (
    traits => [qw(NoGetopt)],
    does => "Data::Stream::Bulk",
    is   => "ro",
    lazy_build => 1,
);

has entries_in_args => (
    traits => [qw(NoGetopt)],
    isa => "Bool",
    is  => "ro",
    default => 0,
);

sub _build_entries {
    my $self = shift;

    my ( @ids, @entries );

    if ( $self->has_ids ) {
        @ids = @{ $self->ids };
    } elsif ( $self->entries_in_args and my $args = $self->args ) {
        @ids = @$args;
    }

    if ( @ids ) {
        @entries = $self->backend->get(@ids);

        if ( @entries != @ids or grep { not defined } @entries ) {
            my %exists;
            @exists{@ids} = $self->backend->exists(@ids);

            my @missing = grep { not $exists{$_} } @ids;

            die "The specified entries do not exist in the database: @missing\n";
        }

        return bulk(@entries);
    } else {
        return $self->backend->all_entries;
    }
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::SpecifiedEntries - A role for command line tools which accept entry IDs as options

=head1 SYNOPSIS

    with qw(KiokuDB::Cmd::SpecifiedEntries)

    augment run => sub {
        ...

        my $data_bulk_stream = $self->entries;
    };

=head1 DESCRIPTION

This role provides L<KiokuDB::Entry> enumeration for command line tools.

If the C<ids> option is specified (it can be given multiple times) then only
those IDs will be loaded into the C<entries> attribute, otherwise
C<all_entries> is called on the backend.
