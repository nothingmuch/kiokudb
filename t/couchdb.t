#!/usr/bin/perl

use Test::More;
use Scope::Guard;

BEGIN {
    plan skip_all => 'Please set KIOKU_COUCHDB_URI to a CouchDB instance URI' unless $ENV{KIOKU_COUCHDB_URI};
    plan 'no_plan';
}

#BEGIN { $KiokuDB::SERIAL_IDS = 1 }

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::CouchDB';

use KiokuDB::Test;

use Net::CouchDB;

my $couch = Net::CouchDB->new($ENV{KIOKU_COUCHDB_URI});

my $name = $ENV{KIOKU_COUCHDB_NAME} || "kioku-$$";

my $keep = exists $ENV{KIOKU_COUCHDB_KEEP} ? $ENV{KIOKU_COUCHDB_KEEP} : exists $ENV{KIOKU_COUCHDB_NAME};

eval { $couch->db($name)->delete };

my $db = $couch->create_db($name);
my $sg = $keep || Scope::Guard->new(sub { $db->delete });

run_all_fixtures(
    KiokuDB->new(
        backend => KiokuDB::Backend::CouchDB->new(
            db => $db,
        ),
    )
);

