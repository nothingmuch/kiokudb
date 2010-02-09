#!/usr/bin/perl

package KiokuDB::LinkChecker;
use Moose;

use KiokuDB::LinkChecker::Results;

use namespace::clean -except => 'meta';

with 'KiokuDB::Role::Scan' => { result_class => "KiokuDB::LinkChecker::Results" };

sub process_block {
    my ( $self, %args ) = @_;

    my ( $block, $res ) = @args{qw(block results)};

    my ( $seen, $root, $referenced, $unreferenced, $missing, $broken ) = map { $res->$_ } qw(seen root referenced unreferenced missing broken);

    my $backend = $self->backend;

    foreach my $entry ( @$block ) {
        my $id = $entry->id;

        $seen->insert($id);
        $root->insert($id) if $entry->root;

        unless ( $referenced->includes($id) ) {
            $unreferenced->insert($id);
        }

        my @ids = $entry->referenced_ids;

        my @new = grep { !$referenced->includes($_) && !$seen->includes($_) } @ids;

        my %exists;
        @exists{@new} = $backend->exists(@new) if @new;

        if ( my @missing = grep { not $exists{$_} } @new ) {
            $self->v("\rfound broken entry: " . $entry->id . " (references nonexisting IDs @missing)\n");
            $missing->insert(@missing);
            $broken->insert($entry->id);
        }

        $referenced->insert(@ids);
        $unreferenced->remove(@ids);
    }
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


