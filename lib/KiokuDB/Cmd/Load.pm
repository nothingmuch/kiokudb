#!/usr/bin/perl

package KiokuDB::Cmd::Load;
use Moose;

use Carp qw(croak);

use MooseX::Types::Path::Class qw(File);

use Moose::Util::TypeConstraints;

use KiokuDB::Entry;
use KiokuDB::Reference;

use namespace::clean -except => 'meta';

with qw(MooseX::Getopt);

has clear => (
    isa => "Bool",
    is  => "ro",
);

has dsn => (
    isa => "Str",
    is  => "ro",
);

has _txn => (
    is => "rw",
);

has backend => (
    does => "KiokuDB::Backend",
    is   => "ro",
    lazy_build => 1,
);

sub _build_backend {
    my $self = shift;

    my $dsn = $self->dsn || croak("'dsn' or 'backend' is required");

    $self->v("Connecting to DSN $dsn...");

    require KiokuDB::Util;
    my $b = KiokuDB::Util::dsn_to_backend( $dsn, create => 1 );

    $self->v(" $b\n");

    if ( $b->does("KiokuDB::Backend::TXN") ) {
        $self->v("starting transaction\n");
        $self->_txn( $b->txn_begin );
    }

    if ( $self->clear ) {
        unless ( $b->does("KiokuDB::Backend::Clear") ) {
            croak "--clear specified but $b does not support clearing";

        }
        $self->v("clearing database....");

        $b->clear;

        $self->v(" done\n");

    }

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

    my $buf = '';

    sub {
        my $fh = shift;

        local $_;
        local $/ = "\n";

        while ( <$fh> ) {
            if ( /^---/ and length($buf) ) {
                my @data = YAML::XS::Load($buf);
                $buf = $_;
                return @data;
            } else {
                $buf .= $_;
            }
        }

        if ( length $buf ) {
            my @data = YAML::XS::Load($buf);
            $buf = '';
            return @data;
        } else {
            return;
        }
    }
}

sub _build_formatter_json {
    require JSON;
    die "json inc parsing";
}

sub _build_formatter_storable {
    require Storable;
    return sub {
        !$_[0]->eof && Storable::fd_retrieve($_[0]) || return ();
    }
}

has file => (
    isa => File,
    is  => "ro",
    coerce => 1,
    predicate => "has_file",
);

has input_handle => (
    isa => "FileHandle",
    is  => "ro",
    lazy_build => 1,
);

sub _build_input_handle {
    my $self = shift;

    if ( $self->has_file ) {
        $self->file->openr;
    } else {
        \*STDIN;
    }
}

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

sub BUILD {
    my $self = shift;

    $self->backend;
    $self->formatter;
    $self->input_handle;
}

sub run {
    my $self = shift;

    my $t = -time();
    my $tc = -times();

    my $b = $self->backend;

    my $in = $self->input_handle;
    my $fmt = $self->formatter;

    my $i = my $j = 0;

    while ( my @entries = $in->$fmt ) {
        if ( $self->verbose ) {
            $i += @entries;
            $j += @entries;

            if ( $j > 13 ) { # luv primes
                $j = 0;
                $self->v("\rloading... $i");
            }
        }

        $b->insert(@entries);
    }

    $self->v("\rloaded $i entries      \n");

    if ( my $txn = $self->_txn ) {
        $self->v("comitting transaction...");
        $b->txn_commit($txn);
        $self->_txn(undef);
        $self->v(" done\n");
    }

    $t += time;
    $tc += times;

    $self->v(sprintf "load finished in %.2fs (%.2fs cpu)\n", $t, $tc);
}


__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::Load - 

=head1 SYNOPSIS

	use KiokuDB::Cmd::Load;

=head1 DESCRIPTION

=cut


