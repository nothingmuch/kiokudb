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

sub _build_entries {
    my $self = shift;

    if ( $self->has_ids ) {
        return bulk($self->backend->get(@{ $self->ids }));
    } else {
        return $self->backend->all_entries;
    }
}

__PACKAGE__

__END__

