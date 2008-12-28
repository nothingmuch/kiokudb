#!/usr/bin/perl

package KiokuDB::Cmd::Command::FSCK;
use Moose;

use KiokuDB::LinkChecker;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Cmd::Base);

with qw(
    KiokuDB::Cmd::WithDSN::Read
    KiokuDB::Cmd::SpecifiedEntries
);

has '+verbose' => ( default => 1 );

has print => (
    isa => "Bool",
    is  => "ro",
    default => 1,
    documentation => "print broken entries to STDOUT at end",
);

augment run => sub {
    my $self = shift;

    my $l = KiokuDB::LinkChecker->new(
        backend => $self->backend,
        entries => $self->entries,
        verbose => $self->verbose,
    );

    if ( $l->missing->size == 0 ) {
        $self->v("No missing entries, everything is OK\n");

        #my $purge = $l->unreferenced->difference($l->root);

        #if ( my $count = $purge->size ) {
        #    $self->v( "$count unreferenced non root objects\n" );
        #}
    } else {
        if ( $self->print ) {
            local $, = local $\ = "\n";
            print STDOUT $l->broken->members;
        }
        $self->exit_code(1);
    }
};

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::Command::FSCK - Check for broken references

=head1 DESCRIPTION

This commands uses L<KiokuDB::LinkChecker> to search for broken references.

=head1 ATTRIBUTES

=over 4

=item print

When true the IDs will be printed to STDOUT, allowing you to dump the broken
entries:

    kioku dump --dsn ... $( kioku fsck --dsn ... --print )

=back

=cut
