#!/usr/bin/perl

package KiokuDB::Cmd::OutputHandle;
use Moose::Role;

use Carp qw(croak);
use MooseX::Types::Path::Class qw(File);

use namespace::clean -except => 'meta';

excludes qw(KiokuDB::Cmd::InputHandle);

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

        $self->v("opening $file for writing\n");

        return $file->openw;
    } else {
        return \*STDOUT;
    }
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::OutputHandle - A role for command line tools with a C<--file>
option that will be used for write access.

=head1 DESCRIPTION

See L<KiokuDB::Cmd::Command::Dump> for an example.

=head1 ATTRIBUTES

=over 4

=item file

The file to open. A L<MooseX::Getopt> enabled attribute.

=item force

Whether to allow overwriting of existing files. A L<MooseX::Getopt> enabled
attribute. When C<backup> is enabled, allows overwriting of the backup file.

=item backup

Whether to backup before overwriting. A L<Moose::Getopt> enabled attribute.

=item backup_ext

Defaults to C<.bak>. A L<MooseX::Getopt> enabled attribute.

=item fh

This filehandle is created based on all the other attributes on demand.

=back
