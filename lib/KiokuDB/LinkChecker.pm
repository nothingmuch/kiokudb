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

    my ( $seen, $referenced, $missing, $broken ) = map { $res->$_ } qw(seen referenced missing broken);

    my $i = my $j = 0;

    while ( my $next = $self->entries->next ) {
        $i += @$next;
        $j += @$next;

        if ( $j > 13 ) { # luv primes
            $j = 0;
            $self->v("\rchecking... $i");
        }

        foreach my $entry ( @$next ) {
            $seen->insert($entry->id);

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

KiokuDB::LinkChecker - 

=head1 SYNOPSIS

	use KiokuDB::LinkChecker;

=head1 DESCRIPTION

=cut


