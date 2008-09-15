#!/usr/bin/perl

use strict;
use warnings;

use Test::TempDir;
use Path::Class;
use Storable qw(nstore retrieve);
use Scalar::Util qw(blessed);

use KiokuDB;
use KiokuDB::Backend::Hash;
use KiokuDB::Backend::JSPON;
use KiokuDB::Backend::BDB;
#use KiokuDB::Backend::CouchDB;

# no long running tests
my $large = 0;

use Benchmark qw(cmpthese);

my $f = (require KiokuDB::Test::Fixture::ObjectGraph)->new;

sub construct {
    $f->create;
}

sub bench {
    my $dir = dir(tempdir);

    my $storable = $dir->file("foo.storable")->stringify;

    my $mxsd_hash = KiokuDB->new(
        backend => KiokuDB::Backend::Hash->new,
    );

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

    my $mxsd_couch;

    if ( my $uri = $ENV{KIOKU_COUCHDB_URI} ) {
        require KiokuDB::Backend::CouchDB;
        require Net::CouchDB;

        my $couch = Net::CouchDB->new($uri);

        my $name = $ENV{KIOKU_COUCHDB_NAME} || "kioku-$$";

        eval { $couch->db($name)->delete };

        my $db = $couch->create_db($name);

        $mxsd_couch = KiokuDB->new(
            backend => KiokuDB::Backend::CouchDB->new(
                db => $db,
            ),
        );

        $mxsd_couch->{__guard} = Scope::Guard->new(sub { $db->delete });
    }

    warn "\nwriting...\n";

    cmpthese(-1, {
        null       => sub { my @objs = construct(); },
        mxsd_hash  => sub { my @objs = construct(); my $s = $mxsd_hash->new_scope; $mxsd_hash->store(grep { blessed($_) } @objs) },
        mxsd_jspon => sub { my @objs = construct(); my $s = $mxsd_jspon->new_scope; $mxsd_jspon->store(grep { blessed($_) } @objs) },
        mxsd_bdb   => sub { my @objs = construct(); my $s = $mxsd_bdb->new_scope; $mxsd_bdb->store(grep { blessed($_) } @objs) },
        ( $mxsd_couch ? ( mxsd_couch => sub { my @objs = construct(); my $s = $mxsd_couch->new_scope; $mxsd_couch->store(grep { blessed($_) } @objs) } ) : () ),
        storable   => sub { nstore([ construct() ], $storable) },
    });

    warn "\nreading...\n";


    my @hash_ids  = do { my @objs = construct(); my $s = $mxsd_hash->new_scope; $mxsd_hash->store(grep { blessed($_) } @objs) };
    my @jspon_ids = do { my @objs = construct(); my $s = $mxsd_jspon->new_scope; $mxsd_jspon->store(grep { blessed($_) } @objs) };
    my @bdb_ids   = do { my @objs = construct(); my $s = $mxsd_bdb->new_scope; $mxsd_bdb->store(grep { blessed($_) } @objs) };
    my @couch_ids = $mxsd_couch ? do { my @objs = construct(); my $s = $mxsd_couch->new_scope; $mxsd_couch->store(grep { blessed($_) } @objs) } : ();

    cmpthese(-1, {
        mxsd_hash  => sub { my $s = $mxsd_hash->new_scope; my @objs = $mxsd_hash->lookup(@hash_ids) },
        mxsd_jspon => sub { my $s = $mxsd_jspon->new_scope; my @objs = $mxsd_jspon->lookup(@jspon_ids) },
        mxsd_bdb   => sub { my $s = $mxsd_bdb->new_scope; my @objs = $mxsd_bdb->lookup(@bdb_ids) },
        ( $mxsd_couch ? ( mxsd_couch => sub { my $s = $mxsd_couch->new_scope; my @objs = $mxsd_couch->lookup(@couch_ids) } ) : () ),
        storable   => sub { my $objs = retrieve($storable) },
    });
}

bench();

