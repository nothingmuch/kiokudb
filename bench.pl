#!/usr/bin/perl

use strict;
use warnings;

use Test::TempDir;
use Path::Class;
use Storable qw(nstore retrieve);
use YAML qw(DumpFile LoadFile);
use DBM::Deep;

use KiokuDB;
use KiokuDB::Backend::JSPON;
use KiokuDB::Backend::BDB;

# no long running tests
my $large = 0;

{
    package Person;
    use Moose;

    use MooseX::Storage;

    with Storage(format => "JSON", io => "File" );

    has name => (
        isa => "Str",
        is  => "rw",
    );

    has age => (
        isa => "Int",
        is  => "rw",
    );

    has parent => (
        isa => "Person",
        is  => "rw",
    );

    package Employee;
    use Moose;

    extends qw(Person);

    has company => (
        isa => "Company",
        is  => "rw",
    );

    package Company;
    use Moose;

    use MooseX::Storage;

    with Storage(format => "JSON", io => "File" );

    has name => (
        isa => "Str",
        is  => "rw",
    );
}

use Benchmark qw(cmpthese);

sub construct {
    return Employee->new(
        name    => "joe",
        age     => 52,
        parent  => Person->new(
            name => "mum",
            age  => 78,
        ),
        company => Company->new(
            name => "OHSOME SOFTWARE KTHX"
        ),
    );
}

sub bench {
    my $dir = dir(tempdir);

    my $json = $dir->file("foo.json")->stringify;
    my $storable = $dir->file("foo.storable")->stringify;
    my $yaml = $dir->file("foo.yaml")->stringify;

    my $mxsd_jspon = KiokuDB->new(
        backend => KiokuDB::Backend::JSPON->new(
            dir  => $dir->subdir("mxsd_jspon"),
            lock => 0,
        ),
    );

    my $mxsd_bdb = KiokuDB->new(
        backend => KiokuDB::Backend::BDB->new(
            dir => $dir->subdir("mxsd_bdb"),
        ),
    );

    my $dbm_deep = DBM::Deep->new( $dir->file("foo.db")->stringify );

    warn "\nwriting...\n";

    cmpthese(-2, {
        null       => sub { construct() },
        mxsd_jspon => sub { $mxsd_jspon->store(construct()) },
        mxsd_bdb   => sub { $mxsd_bdb->store(construct()) },
        mxstorage  => sub { construct->store($json) },
        storable   => sub { nstore(construct(), $storable) },
        yaml       => sub { DumpFile($yaml, construct()) },
        dbmdeep    => sub { $dbm_deep->{Data::GUID->new->as_string} = construct() },
    });

    if ( $large ) {
        warn "\nlarge object set...\n";
        cmpthese(-10, {
            mxsd_jspon => sub { $mxsd_jspon->store(construct()) },
            mxsd_bdb   => sub { $mxsd_bdb->store(construct()) },
            dbmdeep   => sub { $dbm_deep->{Data::GUID->new->as_string} = construct() },
        });
    }

    warn "\nreading...\n";

    my @jspon_ids = $mxsd_jspon->store(map { construct() } 1 .. 5);
    my @bdb_ids   = $mxsd_bdb->store(map { construct() } 1 .. 5);

    my @dbmd_ids  = map { Data::GUID->new->as_string } 1 .. 5;
    $dbm_deep->{$_} = construct() for @dbmd_ids;

    cmpthese(-2, {
        mxsd_jspon => sub { my @objs = $mxsd_jspon->lookup(@jspon_ids) },
        mxsd_bdb   => sub { my @objs = $mxsd_bdb->lookup(@bdb_ids) },
        mxstorage  => sub { my @objs = map { Employee->load($json) } 1 .. 5 },
        storable   => sub { my @objs = map { retrieve($storable) } 1 .. 5 },
        storable   => sub { my @objs = map { LoadFile($yaml) } 1 .. 5 },
        dbmdeep    => sub { my @objs = map { $dbm_deep->{$_} } @dbmd_ids },
    });
}

warn "timing mutable...\n";
bench();

$_->meta->make_immutable for qw(Person Employee Company);

warn "\n\ntiming immutable...\n";
bench();
