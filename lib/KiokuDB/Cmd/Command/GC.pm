#!/usr/bin/perl

package KiokuDB::Cmd::Command::GC;
use Moose;

use Carp qw(croak);

use Moose::Util::TypeConstraints;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Cmd::Base);

with qw(
    KiokuDB::Cmd::WithDSN::Write
    KiokuDB::Cmd::SpecifiedEntries
);

has '+verbose' => ( default => 1 );

has print => (
    traits => [qw(Getopt)],
    isa => "Bool",
    is  => "ro",
    cmd_aliases => "p",
    documentation => "print garbage entries to STDOUT at end",
);

has mode => (
    traits => [qw(Getopt)],
    isa => enum([qw(naive foofoooo)]),
    is  => "ro",
    default => "naive",
    cmd_aliases => "m",
    documentation => "the garbage collection mode to use",
);

my %modes = (
    naive => "KiokuDB::GC::Naive",
);

has class => (
    traits => [qw(Getopt)],
    isa => "Str",
    is  => "ro",
    lazy_build => 1,
    documentation => "explicitly specify the collector class (overrides 'mode')",
);

sub _build_class {
    my $self = shift;

    $modes{$self->mode} or croak "Unknown mode: " . $self->mode;
}

has collector => (
    traits => [qw(NoGetopt)],
    is => "ro",
    lazy_build => 1,
);

sub _build_collector {
    my $self = shift;

    my $class = $self->class;

    Class::MOP::load_class($class);

    $class->new(
        backend => $self->backend,
        verbose => $self->verbose,
    );
}

augment run => sub {
    my $self = shift;

    my $g = $self->collector->garbage;

    if ( $g->size ) {
        $self->v(sprintf "found %d dead objects\n", $g->size);

        if ( $self->print ) {
            local $, = local $\ = "\n";
            print STDOUT $g->members;
        } else {
            $self->v("cleaning...\n");
            $self->backend->delete( $g->members ) unless $self->dry_run;
        }
    } else {
        $self->v("no dead objects\n");
    }

    $self->try_txn_commit( $self->backend );
};

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::Command::GC - Collect unreachable entries

=head1 SYNOPSIS

    % kioku gc --dry-run -D bdb-gin:dir=data/

=head1 DESCRIPTION

Runs garbage collection on a specified database.

=head1 ATTRIBUTES

=over 4

=item print

When true the IDs will be printed to STDOUT, instead of being deleted.

=back

=cut
