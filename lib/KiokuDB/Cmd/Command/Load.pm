#!/usr/bin/perl

package KiokuDB::Cmd::Command::Load;
use Moose;

use MooseX::Types::Path::Class qw(File);

use Moose::Util::TypeConstraints;

use KiokuDB::Entry;
use KiokuDB::Reference;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Cmd::Base);

with qw(
    KiokuDB::Cmd::WithDSN::Create
);

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
    cmd_aliases => "i",
    documentation => "input file (defaults to STDIN)",
);

has input_handle => (
    traits => [qw(NoGetopt)],
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

sub BUILD {
    my $self = shift;

    unless ( $self->app ) {
        $self->backend;
        $self->formatter;
        $self->input_handle;
    }
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

    $self->try_txn_commit($b);

    $t += time;
    $tc += times;

    $self->v(sprintf "load finished in %.2fs (%.2fs cpu)\n", $t, $tc);
}


__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::Command::Load - Load database dumps

=head1 SYNOPSIS

    # command line API
    # dump whole database to foo.yml sequentially

    % kiokuload --verbose --file foo.yml --format yaml --clear --dsn bdb-gin:dir=data/


    # programmatic API

    use KiokuDB::Cmd::Command::Load;

    my $loader = KiokuDB::Cmd::Command::Load->new(
        backend => $backend,
        formatter => sub { ... },
        input_handle => $fh,
    );

    $dumper->run;


=head1 DESCRIPTION

This class loads dumps created by L<KiokuDB::Cmd::Command::Dump>.

Entries will be read sequentially from C<input_handle>, deserialized, and
inserted into the database.

If the backend supports L<KiokuDB::Backend::Role::TXN> then the load is performed in
a single transaction.

=head1 COMMAND LINE API

This class uses L<MooseX::Getopt> to provide a command line api.

The command line options map to the class attributes.

=head1 METHODS

=over 4

=item new_with_options

Provided by L<MooseX::Getopt>. Parses attributes init args from C<@ARGV>.

=item run

Performs the actual load.

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

C<formatter> is a code reference that is provided with a file handle and should
return at least one entry object.

It is applied to the handle repeatedly until no more entries are returned.

=item clear

If set, L<KiokuDB::Backend::Role::Clear>'s interface will be used to wipe the
database before loading.

=item file

=item input_handle

C<input_handle> is where entries will be read from.

If it isn't provided and then C<file> will be opened for reading.

If C<file> isn't provided C<STDIN> will be used.

=item verbose

If enabled causes progress information to be printed to C<STDERR>.

=back

=cut


