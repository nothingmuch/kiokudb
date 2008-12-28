#!/usr/bin/perl

package KiokuDB::LinkChecker;
use Moose;

use KiokuDB::LinkChecker::Results;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Cmd::Verbosity);

has backend => (
    does => "KiokuDB::Backend",
    is   => "ro",
    required => 1,
);

has entries => (
    does => "Data::Stream::Bulk",
    is   => "ro",
    lazy_build => 1,
);

sub _build_entries {
    shift->backend->all_entries;
}

has [qw(block_callback entry_callback)] => (
    isa => "CodeRef|Str",
    is  => "ro",
);

has results => (
    isa => "KiokuDB::LinkChecker::Results",
    handles => qr/.*/,
    lazy_build => 1,
);

sub _build_results {
    my $self = shift;

    my $res = KiokuDB::LinkChecker::Results->new;

    my ( $seen, $root, $referenced, $unreferenced, $missing, $broken ) = map { $res->$_ } qw(seen root referenced unreferenced missing broken);

    my $i = my $j = 0;

    while ( my $next = $self->entries->next ) {
        $i += @$next;
        $j += @$next;

        if ( $j > 13 ) { # luv primes
            $j = 0;
            $self->v("\rchecking... $i");
        }

        foreach my $entry ( @$next ) {
            my $id = $entry->id;

            $seen->insert($id);
            $root->insert($id) if $entry->root;

            unless ( $referenced->includes($id) ) {
                $unreferenced->insert($id);
            }

            my @ids = $entry->referenced_ids;

            my @new = grep { !$referenced->includes($_) && !$seen->includes($_) } @ids;

            my %exists;
            @exists{@new} = $self->backend->exists(@new);

            if ( my @missing = grep { not $exists{$_} } @new ) {
                $self->v("\rfound broken entry: " . $entry->id . " (references nonexisting IDs @missing)\n");
                $missing->insert(@missing);
                $broken->insert($entry->id);
            }

            $referenced->insert(@ids);
            $unreferenced->remove(@ids);
        }
    }

    $self->v("\rchecked $i entries      \n");

    return $res;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::LinkChecker - Reference consistency checker

=head1 SYNOPSIS

    use KiokuDB::LinkChecker;

    my $l = KiokuDB::LinkChecker->new(
        backend => $b,
    );

    my @idw = $l->missing->members; # referenced but not in the DB

=head1 DESCRIPTION

This is the low level link checker used by L<KiokuDB::Cmd::Command::FSCK>.

=cut


