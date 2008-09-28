#!/usr/bin/perl

package KiokuDB::Cmd::Dump;
use Moose;

use KiokuDB::Backend::Scan ();

use Carp qw(croak);

BEGIN { local $@; eval "use Time::HiRes qw(time)" };

use MooseX::Types::Path::Class qw(File);

use Moose::Util::TypeConstraints;

use namespace::clean -except => 'meta';

with qw(MooseX::Getopt);

has dsn => (
    isa => "Str",
    is  => "ro",
);

has backend => (
    does => "KiokuDB::Backend::Scan",
    is   => "ro",
    lazy_build => 1,
);

sub _build_backend {
    my $self = shift;

    my $dsn = $self->dsn || croak("'dsn' or 'backend' is required");

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
);

has formatter => (
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
);

has force => (
    isa => "Bool",
    is  => "ro",
);

has backup => (
    isa => "Bool",
    is  => "ro",
);

has backup_ext => (
    isa => "Str",
    is  => "ro",
    default => ".bak",
);

has output_handle => (
    isa => "FileHandle",
    is  => "ro",
    lazy_build => 1,
);

has verbose => (
    isa => "Bool",
    is  => "ro",
);

sub v {
    my $self = shift;
    return unless $self->verbose;

    STDERR->autoflush(1);
    STDERR->print(@_);
}

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

    $self->backend;
    $self->formatter;
    $self->output_handle;
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

KiokuDB::Cmd::Dump - 

=head1 SYNOPSIS

	use KiokuDB::Cmd::Dump;

=head1 DESCRIPTION

=cut



