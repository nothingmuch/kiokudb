#!/usr/bin/perl

package KiokuDB::Cmd::Command::FSCK;
use Moose;

use KiokuDB::LinkChecker;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Cmd::Base);

with qw(
    KiokuDB::Cmd::WithDSN::Read
);

has '+verbose' => ( default => 1 );

augment run => sub {
    my $self = shift;

    my $l = KiokuDB::LinkChecker->new( backend => $self->backend, verbose => $self->verbose );

    if ( $l->missing->size == 0 ) {
        $self->v("No missing entries, everything is OK\n");
    } else {
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

=cut
