#!/usr/bin/perl

package KiokuDB::Cmd::OutputHandle;
use Moose::Role;

use Carp qw(croak);
use MooseX::Types::Path::Class qw(File);

use namespace::clean -except => 'meta';

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
    traits => [qw(NoGetopt EarlyBuild)],
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
