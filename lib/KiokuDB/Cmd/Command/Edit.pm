#!/usr/bin/perl

package KiokuDB::Cmd::Command::Edit;
use Moose;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Cmd::Base);

with qw(
    KiokuDB::Cmd::WithDSN::Write
    KiokuDB::Cmd::DumpFormatter
    KiokuDB::Cmd::SpecifiedEntries
);

has '+entries_in_args' => ( default => 1 );

has '+ids' => ( required => 1 );

has '+verbose' => ( default => 1 );

has 'editor' => (
    traits => [qw(Getopt)],
    isa => "Str",
    is  => "ro",
    predicate => "has_editor",
    documentation => "override the default editor (see Proc::InvokeEditor)",
);

augment run => sub {
    my $self = shift;

    my @entries = $self->entries->all;

    my $ser = $self->serializer;

    my $buf;

    {
        open my $fh, ">", \$buf;
        $ser->serialize_to_stream($fh, $_) for @entries;
    }

    require Proc::InvokeEditor;

    my $editor = Proc::InvokeEditor->new( $self->has_editor ? ( editors => [ $self->editor ] ) : () );

    my $new = $editor->edit( $buf, $ser->can("file_extension") ? ( "." . $ser->file_extension ) : () );

    if ( $new ne $buf ) {
        $self->v("loading\n");

        my @loaded;

        {
            open my $fh, "<", \$new;
            while ( my @entries = $ser->deserialize_from_stream($fh) ) {
                push @loaded, @entries;
            }
        }

        my %prev = map { $_->id => $_ } @entries;

        my %new = map { $_->id => $_ } @loaded;

        my %update;

        foreach my $id ( keys %new ) {
            if ( my $prev = delete $prev{$id} ) {
                my $entry = $update{$id} = delete $new{$id};
                $entry->prev($prev);
            }
        }

        my @delete = keys %prev;

        {
            local $" = ", ";
            $self->v("deleting @delete\n") if @delete;
            $self->v("updating @{[ keys %update ]}\n") if keys %update;
            $self->v("inserting @{[ keys %new ]}\n") if keys %new;
        }

        unless ( $self->dry_run ) {
            $self->backend->delete(@delete);
            $self->backend->insert(values %new, values %update);

            $self->try_txn_commit($self->backend);
        }
    } else {
        $self->v("no changes.\n");
    }
};

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::Command::Edit - Edit entries using an editor

=head1 SYNOPSIS

    % kioku edit -i $id -D bdb-gin:dir=foo/bar

=head1 DESCRIPTION

This command uses L<Proc::InvokeEditor> to edit specified entries interactively.

New entries can be added and existing ones renamed or deleted. Note that no
effort is made to update links to renamed entries. It is reccomended that you
run the fsck command after editing.

=head1 ATTRIBUTES

=over 4

=item dsn

=item backend

C<dsn> is a string and thus can be used on the command line. C<backend> is
defined in terms of C<dsn> if it isn't provided.

=item editor

Override the default editor chosen by L<Proc::InvokeEditor>.

=item format

=item formatter

C<format> is one of C<yaml>, C<storable> or C<json>, defaulting to C<yaml>.

C<formatter> is a code reference which takes an entry as an argument. It is
created from a set of defaults using C<format> if it isn't provided.

=item verbose

If enabled causes progress information to be printed to C<STDERR>.

=back

=cut



