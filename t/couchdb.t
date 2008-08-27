#!/usr/bin/perl

use Test::More;

BEGIN {
    plan skip_all => 'Please set NET_COUCHDB_URI to a CouchDB instance URI' unless $ENV{TEST_COUCHDB_URI};
    plan 'no_plan';
}

#BEGIN { $KiokuDB::SERIAL_IDS = 1 }

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::CouchDB';

use Net::CouchDB;

my $couch = Net::CouchDB->new($ENV{TEST_COUCHDB_URI});

eval { $couch->db("mxsd")->delete };

my $db = $couch->create_db("mxsd");

my $dir = KiokuDB->new(
    backend => KiokuDB::Backend::CouchDB->new(
        db => $db,
    ),
    #backend => KiokuDB::Backend::JSPON->new(
    #    dir    => temp_root,
    #    pretty => 1,
    #    lock   => 0,
    #),
);

use ok 'KiokuDB::Test::Fixture::Person';

my $f = KiokuDB::Test::Fixture::Person->new( directory => $dir );

$f->populate;

$f->verify;

