#!/usr/bin/perl

package KiokuDB::Cmd::Command::Dump;
use Moose;

use KiokuDB::Backend::Role::Scan ();

use Carp qw(croak);

BEGIN { local $@; eval "use Time::HiRes qw(time)" };

use MooseX::Types::Path::Class qw(File);

use Moose::Util::TypeConstraints;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Cmd::Base);

with qw(
    KiokuDB::Cmd::WithDSN
);

sub _build_backend {
    my $self = shift;

    my $dsn = $self->dsn || croak("--dsn is required");

    $self->v("Connecting to DSN $dsn...");

    require KiokuDB::Util;
    my $b = KiokuDB::Util::dsn_to_backend( $dsn, readonly => 1 );

    $self->v(" $b\n");

    $b;
}

has format => (
    isa => enum([qw(yaml json storable)]),
    is  => "ro",
    default => "yaml",
    cmd_aliases => "f",
    documentation => "dump format ('yaml', 'storable', etc)"
);

has formatter => (
    traits => [qw(NoGetopt)],
    isa => "CodeRef",
    is  => "ro",
    lazy_build => 1,
);

sub _build_formatter {
    my $self = shift;
    my $builder = "_build_formatter_" . $self->format;
    $self->$builder;
}

sub _build_formatter_yaml {
    require YAML::XS;
    sub { $_[1]->print(YAML::XS::Dump($_[0])) };
}

sub _build_formatter_json {
    require JSON;
    my $json = JSON->new->utf8;
    sub { $_[1]->print($json->encode($_[0])) }
}

sub _build_formatter_storable {
    require Storable;
    return \&Storable::nstore_fd;
}

has file => (
    isa => File,
    is  => "ro",
    coerce => 1,
    cmd_aliases => "o",
    documentation => "output file (defaults to STDOUT)",
);

has force => (
    isa => "Bool",
    is  => "ro",
    cmd_aliases => "F",
    documentation => "allow overwriting of files",
);

has backup => (
    isa => "Bool",
    is  => "ro",
    cmd_aliases => "b",
    documentation => "rename file before writing",
);

has backup_ext => (
    isa => "Str",
    is  => "ro",
    default => ".bak",
    cmd_aliases => "B",
    documentation => "backup extension (defaults to .bak)",
);

has output_handle => (
    traits => [qw(NoGetopt)],
    isa => "FileHandle",
    is  => "ro",
    lazy_build => 1,
);

sub _build_output_handle {
    my $self = shift;

    if ( my $file = $self->file ) {
        if ( -e $file ) {
            if ( $self->backup ) {
                my $backup = $file . $self->backup_ext;

                if ( -e $backup && !$self->force ) {
                    croak "backup file $backup exists but --force not specified";
                }

                $self->v("backing up $file to $backup\n");

                unless ( rename $file, $backup ) {
                    croak "renaming of $file to $backup failed"
                }
            } elsif ( !$self->force ) {
                croak "$file exists but neither --force nor --backup is specified";
            }
        }

        $self->v("openining $file for writing\n");

        return $file->openw;
    } else {
        return \*STDOUT;
    }
}

sub BUILD {
    my $self = shift;

    unless ( $self->app ) {
        $self->backend;
        $self->formatter;
        $self->output_handle;
    }
}

sub run {
    my $self = shift;

    my $t = -time();
    my $tc = -times();

    $self->v("dumping entries\n");

    my $stream = $self->backend->all_entries;

    my $out = $self->output_handle;
    my $fmt = $self->formatter;

    my $i;

    while ( $self->v("loading block #", ++$i, "..."), my $block = $stream->next ) {
        $self->v(" dumping ", scalar(@$block), " entries...");
        foreach my $entry ( @$block ) {
            $entry->$fmt($out);
        }
        $self->v(" done.\n");
    }

    $t += time;
    $tc += times;

    $self->v(sprintf " no blocks remain.\ndump completed in %.2fs (%.2fs cpu)\n", $t, $tc);
}

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



