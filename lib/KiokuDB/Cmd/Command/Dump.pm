#!/usr/bin/perl

package KiokuDB::Cmd::Command::Dump;
use Moose;

use KiokuDB::Backend::Role::Scan ();

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Cmd::Base);

with qw(
    KiokuDB::Cmd::WithDSN::Read
    KiokuDB::Cmd::DumpFormatter
    KiokuDB::Cmd::SpecifiedEntries
    KiokuDB::Cmd::OutputHandle
);

has '+entries_in_args' => ( default => 1 );

augment run => sub {
    my $self = shift;

    $self->v("dumping entries\n");

    my $stream = $self->entries;

    my $out = $self->output_handle;
    my $ser = $self->serializer;

    my $i;

    while ( $self->v("loading block #", ++$i, "..."), my $block = $stream->next ) {
        $self->v(" dumping ", scalar(@$block), " entries...");
        foreach my $entry ( @$block ) {
            $ser->serialize_to_stream($out, $entry);
        }
        $self->v(" done.\n");
    }

    $self->v("\r                             \r");
    $self->v("no blocks remain.\n");
};

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::Command::Dump - Dump database entries for backup or munging purposes

=head1 SYNOPSIS

    # command line API
    # dump whole database to foo.yml sequentially

    % kiokudump --verbose --file foo.yml --format yaml --backup --dsn bdb-gin:dir=data/



    # programmatic API

    use KiokuDB::Cmd::Command::Dump;

    my $dumper = KiokuDB::Cmd::Command::Dump->new(
        backend => $backend,
        formatter => sub { ... },
        output_handle => $fh,
    );

    $dumper->run;

=head1 DESCRIPTION

Using the L<KiokuDB::Backend::Role::Scan> interface, any supporting backend can be
dumped using this api.

The data can then be edited or simply retained for backup purposes.

The data can be loaded using L<KiokuDB::Cmd::Command::Load>.

=head1 COMMAND LINE API

This class uses L<MooseX::Getopt> to provide a command line api.

The command line options map to the class attributes.

=head1 METHODS

=over 4

=item new_with_options

Provided by L<MooseX::Getopt>. Parses attributes init args from C<@ARGV>.

=item run

Performs the actual dump.

=back

=head1 ATTRIBUTES

=over 4

=item dsn

=item backend

The backend to be dumped.

C<dsn> is a string and thus can be used on the command line. C<backend> is
defined in terms of C<dsn> if it isn't provided.

=item format

=item formatter

C<format> is one of C<yaml>, C<storable> or C<json>, defaulting to C<yaml>.

C<formatter> is a code reference which takes an entry as an argument. It is
created from a set of defaults using C<format> if it isn't provided.

=item file

=item backup

=item force

=item backup_ext

=item output_handle

C<output_handle> is where the returned string of C<formatter> will be printed.

If it isn't provided, C<file> will be opened for writing. If the file already
exists and C<force> is specified, it will be overwritten. If C<backup> is
provided the original will first be renamed using C<backup_ext> (defaults to
C<.bak>). If the backup already exists, then C<force> will allow overwriting of
the previous backup.

If no file is provided then C<STDOUT> is used.

=item verbose

If enabled causes progress information to be printed to C<STDERR>.

=back

=cut



