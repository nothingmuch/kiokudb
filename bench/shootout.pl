#!/usr/bin/perl

use strict;
use warnings;

use Test::TempDir;
use Path::Class;
use Storable qw(nstore retrieve);

use KiokuDB;
use KiokuDB::Backend::Hash;
use KiokuDB::Backend::JSPON;
use KiokuDB::Backend::BDB;
#use KiokuDB::Backend::CouchDB;

use Data::Structure::Util qw(circular_off);
#sub circular_off {}

# no long running tests
my $large = 0;

use Benchmark qw(cmpthese);

my $f = (require KiokuDB::Test::Fixture::ObjectGraph)->new;

BEGIN { *uuid = \&KiokuDB::Role::UUIDs::generate_uuid }

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

    #my $dbm_deep = DBM::Deep->new( $dir->file("foo.db")->stringify );

    warn "\nwriting...\n";

    cmpthese(-1, {
        null       => sub { my @objs = construct(); circular_off(\@objs) },
        mxsd_hash  => sub { my @objs = construct(); $mxsd_hash->store(@objs); circular_off(\@objs) },
        mxsd_jspon => sub { my @objs = construct(); $mxsd_jspon->store(@objs); circular_off(\@objs) },
        mxsd_bdb   => sub { my @objs = construct(); $mxsd_bdb->store(@objs); circular_off(\@objs) },
        ( $mxsd_couch ? ( mxsd_couch => sub { my @objs = construct(); $mxsd_couch->store(@objs); circular_off(\@objs) } ) : () ),
        storable   => sub { my @objs = construct(); nstore(\@objs, $storable); circular_off(\@objs) },
        #dbmdeep    => sub { my @objs = construct(); @{ $dbm_deep }{uuid(), uuid()} = @objs; circular_off(\@objs) }, # bus errors on large object graph
    });

    warn "\nreading...\n";

    my @hash_ids  = $mxsd_hash->store(construct());
    my @jspon_ids = $mxsd_jspon->store(construct());
    my @bdb_ids   = $mxsd_bdb->store(construct());
    my @couch_ids = $mxsd_couch ? $mxsd_couch->store(construct()) : ();

    #my @dbmd = construct();
    #my @dbmd_ids  = map { uuid() } @dbmd;;
    #@{ $dbm_deep }{@dbmd_ids} = @dbmd;

    cmpthese(-1, {
        mxsd_hash  => sub { my @objs = $mxsd_hash->lookup(@hash_ids); circular_off(\@objs) },
        mxsd_jspon => sub { my @objs = $mxsd_jspon->lookup(@jspon_ids); circular_off(\@objs) },
        mxsd_bdb   => sub { my @objs = $mxsd_bdb->lookup(@bdb_ids); circular_off(\@objs) },
        ( $mxsd_couch ? ( mxsd_couch => sub { my @objs = $mxsd_couch->lookup(@couch_ids); circular_off(\@objs) } ) : () ),
        storable   => sub { my $objs = retrieve($storable); circular_off($objs) },
        #dbmdeep    => sub { my @objs = @{ $dbm_deep }{@dbmd_ids}; circular_off(\@objs) },
    });
}

bench();

